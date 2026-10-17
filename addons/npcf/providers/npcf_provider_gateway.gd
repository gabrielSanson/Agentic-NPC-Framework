class_name NpcfProviderGateway
extends Node
## Owns every provider: health checks, one request in flight per provider, a bounded queue, timeouts. Never
## blocks: poll() (called every frame by _process) advances everything. Every send gets exactly one callback.

signal status_changed(id: StringName, state: StringName, reason: String)

const AUTH_PREFIX: String = "Authorization: Bearer "


## A request waiting for the one in flight.
class _Pending extends RefCounted:
	var spec: NpcfHttpSpec
	var on_done: Callable
	var on_chunk: Callable
	var replace_key: StringName = &""


## Per provider state. active_done is the callback of the request in flight, kept so close() can answer it.
class _Entry extends RefCounted:
	var cfg: NpcfProviderConfig
	var adapter: NpcfProviderAdapter = null
	var endpoint: NpcfEndpoint = null
	var state: StringName = &"checking"
	var reason: String = ""
	var active: NpcfHttpCall = null
	var active_done: Callable = Callable()
	var health: NpcfHttpCall = null
	var queue: Array[_Pending] = []
	var recheck_at_ms: int = -1


var _entries: Dictionary[StringName, _Entry] = {}
var _order: Array[StringName] = []
var _closed: bool = false


func _process(_delta: float) -> void:
	poll()


func _exit_tree() -> void:
	close()


## Adds one provider and starts its health check. Returns OK, or ERR_INVALID_PARAMETER when the config or the
## adapter is refused (the entry is kept, with state &"refused", so status() can report why).
func add_provider(cfg: NpcfProviderConfig) -> Error:
	if _entries.has(cfg.id):
		push_error("npcf: provider %s is already added" % cfg.id)
		return ERR_ALREADY_EXISTS
	var e: _Entry = _Entry.new()
	e.cfg = cfg
	e.endpoint = NpcfEndpoint.parse(cfg.base_url)
	_entries[cfg.id] = e
	_order.append(cfg.id)
	var problems: PackedStringArray = []
	for msg: String in cfg.check():
		problems.append("%s: %s" % [cfg.id, msg])
	e.adapter = _make_adapter(cfg.adapter)
	if e.adapter == null:
		problems.append("%s: unknown adapter \"%s\"" % [cfg.id, cfg.adapter])
	elif e.adapter.kind() != cfg.kind:
		problems.append("%s: adapter \"%s\" does not serve kind %s" % [cfg.id, cfg.adapter, NpcfProviderConfig.Kind.keys()[cfg.kind]])
	if not problems.is_empty():
		_set_state(e, &"refused", "; ".join(problems))
		return ERR_INVALID_PARAMETER
	_start_health(e, Time.get_ticks_msec())
	return OK


func adapter(id: StringName) -> NpcfProviderAdapter:
	var e: _Entry = _entry(id)
	return e.adapter if e != null else null


func config(id: StringName) -> NpcfProviderConfig:
	var e: _Entry = _entry(id)
	return e.cfg if e != null else null


func state(id: StringName) -> StringName:
	var e: _Entry = _entry(id)
	return e.state if e != null else &"unknown"


func reason(id: StringName) -> String:
	var e: _Entry = _entry(id)
	return e.reason if e != null else ""


func is_ready(id: StringName) -> bool:
	return state(id) == &"ready"


func ids() -> Array[StringName]:
	return _order.duplicate()


## The first provider in add order that is ready and has `use` in use_for, else &"".
func first_ready_for(use: StringName) -> StringName:
	for id: StringName in _order:
		var e: _Entry = _entries[id]
		if e.state == &"ready" and e.cfg.use_for.has(use):
			return id
	return &""


## Sends one request. on_done gets exactly one NpcfHttpResult. A not-ready provider answers &"down" at once.
func send(id: StringName, spec: NpcfHttpSpec, on_done: Callable, on_chunk: Callable = Callable(),
		replace_key: StringName = &"") -> void:
	var e: _Entry = _entry(id)
	if e == null or _closed or e.state != &"ready":
		on_done.call(NpcfHttpResult.make(&"down"))
		return
	var pend: _Pending = _Pending.new()
	pend.spec = spec
	pend.on_done = on_done
	pend.on_chunk = on_chunk
	pend.replace_key = replace_key
	if e.active == null and e.queue.is_empty():
		_launch(e, pend)
		return
	if replace_key != &"":
		for i: int in e.queue.size():
			if e.queue[i].replace_key == replace_key:
				var old: _Pending = e.queue[i]
				e.queue.remove_at(i)
				old.on_done.call(NpcfHttpResult.make(&"dropped"))
				e.queue.append(pend)
				return
	if e.queue.size() >= e.cfg.max_queue:
		on_done.call(NpcfHttpResult.make(&"busy"))
		return
	e.queue.append(pend)


## Advances every provider. Called every frame by _process; tests and the CLI call it directly.
func poll() -> void:
	var now: int = Time.get_ticks_msec()
	for id: StringName in _order.duplicate():
		var e: _Entry = _entries[id]
		if e.health != null:
			e.health.poll(now)
		if e.active != null:
			e.active.poll(now)
		if e.health == null and e.active == null and e.recheck_at_ms >= 0 and now >= e.recheck_at_ms:
			_start_health(e, now)


## Polls until no provider is checking, or max_ms passes. also_poll (when valid) runs on every pass; the CLI and
## tests use it to drive a server in the same process.
func check_all_blocking(max_ms: int, also_poll: Callable = Callable()) -> void:
	var deadline: int = Time.get_ticks_msec() + max_ms
	while _any_checking() and Time.get_ticks_msec() < deadline:
		poll()
		if also_poll.is_valid():
			also_poll.call()
		OS.delay_msec(2)


## Cancels every call and answers every active and queued request with &"down". Later sends answer &"down".
func close() -> void:
	_closed = true
	for id: StringName in _order:
		var e: _Entry = _entries[id]
		e.recheck_at_ms = -1
		if e.health != null:
			var h: NpcfHttpCall = e.health
			e.health = null
			h.cancel()
		if e.active != null:
			var a: NpcfHttpCall = e.active
			var cb: Callable = e.active_done
			e.active = null
			e.active_done = Callable()
			a.cancel()
			cb.call(NpcfHttpResult.make(&"down"))
		var waiting: Array[_Pending] = e.queue.duplicate()
		e.queue.clear()
		for p: _Pending in waiting:
			p.on_done.call(NpcfHttpResult.make(&"down"))
		if e.state != &"down" and e.state != &"refused":
			_set_state(e, &"down", "gateway closed")


func _entry(id: StringName) -> _Entry:
	if not _entries.has(id):
		return null
	return _entries[id]


func _any_checking() -> bool:
	for id: StringName in _order:
		if _entries[id].state == &"checking":
			return true
	return false


func _set_state(e: _Entry, new_state: StringName, why: String) -> void:
	e.state = new_state
	e.reason = why
	status_changed.emit(e.cfg.id, new_state, why)


## Starts a health check, or (when the key variable is still empty) keeps the provider down until the next recheck.
func _start_health(e: _Entry, now: int) -> void:
	e.recheck_at_ms = -1
	if e.cfg.key_env != "" and OS.get_environment(e.cfg.key_env) == "":
		_set_state(e, &"down", "environment variable %s is empty" % e.cfg.key_env)
		e.recheck_at_ms = now + e.cfg.retry_ms
		return
	_set_state(e, &"checking", "")
	var spec: NpcfHttpSpec = e.adapter.health_spec(e.cfg)
	_add_auth(e, spec)
	var call: NpcfHttpCall = NpcfHttpCall.new(spec, e.endpoint, _on_health.bind(e))
	e.health = call
	call.start(now)


func _on_health(r: NpcfHttpResult, e: _Entry) -> void:
	e.health = null
	if e.adapter.health_ok(r):
		e.recheck_at_ms = -1
		_set_state(e, &"ready", "")
		return
	_set_state(e, &"down", "health check: %s %d" % [r.status, r.code])
	e.recheck_at_ms = Time.get_ticks_msec() + e.cfg.retry_ms


## Starts a queued or new request. The callback is stored first, so a request that fails at once still finds it.
func _launch(e: _Entry, pend: _Pending) -> void:
	_add_auth(e, pend.spec)
	var call: NpcfHttpCall = NpcfHttpCall.new(pend.spec, e.endpoint, _on_active_done.bind(e, pend.on_done), pend.on_chunk)
	e.active = call
	e.active_done = pend.on_done
	call.start(Time.get_ticks_msec())


func _on_active_done(r: NpcfHttpResult, e: _Entry, cb: Callable) -> void:
	e.active = null
	e.active_done = Callable()
	if r.status == &"refused":
		_set_state(e, &"down", "connection refused")
		e.recheck_at_ms = Time.get_ticks_msec() + e.cfg.retry_ms
		var waiting: Array[_Pending] = e.queue.duplicate()
		e.queue.clear()
		for p: _Pending in waiting:
			p.on_done.call(NpcfHttpResult.make(&"down"))
	cb.call(r)
	_start_next(e)


func _start_next(e: _Entry) -> void:
	if e.state != &"ready" or e.active != null or e.queue.is_empty():
		return
	var pend: _Pending = e.queue.pop_front()
	_launch(e, pend)


## Adds the bearer header when the provider names a key variable. The key is read here and kept nowhere else.
func _add_auth(e: _Entry, spec: NpcfHttpSpec) -> void:
	if e.cfg.key_env == "":
		return
	spec.headers.append(AUTH_PREFIX + OS.get_environment(e.cfg.key_env))


## Adapter registry. C3b and C3c add their own arms.
func _make_adapter(adapter_name: StringName) -> NpcfProviderAdapter:
	match adapter_name:
		&"openai_chat":
			return NpcfOpenAiChatAdapter.new()
	return null
