class_name NpcfHookRunner
extends RefCounted
## The only way pack code runs inside the core (R2.4, R18). Calls a hook through Callable.callv,
## detects runtime errors with NpcfErrorProbe, validates the returned value's type, range and
## finiteness, and returns the documented safe default on any failure. Failures are logged with
## pack, hook, NPC and tick, and counted per hook script.
##
## An infinite loop inside a hook cannot be isolated; packs are trusted code (README threat model).

## Current tick, set by the world at the start of each step (for failure logs).
var tick: int = 0
## Failure count per hook script path.
var failures: Dictionary[String, int] = {}
## When false, failures are counted but not pushed as warnings (tests of expected failures).
var log_failures: bool = true

var _pack_namespace: StringName = &""
var _instances: Dictionary[String, RefCounted] = {}
var _probe: NpcfErrorProbe = NpcfErrorProbe.new()
var _probe_registered: bool = false


func _init(pack_namespace: StringName = &"") -> void:
	_pack_namespace = pack_namespace
	OS.add_logger(_probe)
	_probe_registered = true


## Unregisters the error probe. The world calls this when it is disposed.
func dispose() -> void:
	if _probe_registered:
		OS.remove_logger(_probe)
		_probe_registered = false


## The shared instance of a hook script (hooks are stateless; one instance per script).
func instance(script: Script) -> RefCounted:
	var key: String = script.resource_path if script.resource_path != "" else str(script.get_instance_id())
	var inst: RefCounted = _instances.get(key)
	if inst == null:
		var obj: Variant = script.call("new")
		if obj is RefCounted:
			inst = obj
			_instances[key] = inst
	return inst


func consideration(hook: Script, view: NpcfNpcView, params: NpcfHookParams) -> float:
	var r: Variant = _call(hook, &"evaluate", [view, params], view.npc_id())
	if r is float or r is int:
		var f: float = r
		if is_finite(f) and f >= 0.0 and f <= 1.0:
			return f
		_fail(hook, view.npc_id(), "returned %s, outside 0..1" % str(r))
	return 0.0


func condition(hook: Script, view: NpcfNpcView, args: Dictionary[StringName, Variant]) -> bool:
	var r: Variant = _call(hook, &"check", [view, args], view.npc_id())
	if r is bool:
		var ok: bool = r
		return ok
	return false


## The computed changes, or null when the hook failed (the action then fails with `hook_error`).
func effect(hook: Script, view: NpcfNpcView, args: Dictionary[StringName, Variant]) -> Variant:
	var r: Variant = _call(hook, &"compute", [view, args], view.npc_id())
	if r == null:
		return null
	var out: Array[NpcfStateChange] = []
	if not _typed_array(r, out, hook, view.npc_id()):
		return null
	return out


func mapper(hook: Script, event: NpcfEventView, receiver: StringName) -> Array[NpcfFact]:
	var r: Variant = _call(hook, &"map_event", [event, receiver], receiver)
	var out: Array[NpcfFact] = []
	if r == null or not _typed_array(r, out, hook, receiver):
		return []
	return out


## RUNNING, SUCCESS or FAILURE (NpcfResolverHook constants); FAILURE on any failure.
func resolver(hook: Script, call_view: NpcfActionCallView, world: NpcfWorldView, elapsed: int) -> int:
	var r: Variant = _call(hook, &"resolve", [call_view, world, elapsed], call_view.npc())
	if r is int:
		var status: int = r
		if status == NpcfResolverHook.RUNNING or status == NpcfResolverHook.SUCCESS or status == NpcfResolverHook.FAILURE:
			return status
		if r != null and not _errored:
			_fail(hook, call_view.npc(), "returned %d, not RUNNING, SUCCESS or FAILURE" % status)
	return NpcfResolverHook.FAILURE


## A plan, or null when the hook failed or found no plan.
func planner(hook: Script, goal: NpcfGoalDef, view: NpcfNpcView, legal: NpcfLegalActions, budget: NpcfPlanBudget) -> NpcfPlan:
	var r: Variant = _call(hook, &"plan", [goal, view, legal, budget], view.npc_id())
	if r is NpcfPlan:
		var p: NpcfPlan = r
		return p
	return null


func invariant(hook: Script, world: NpcfWorldView, invariant_id: StringName) -> Array[NpcfInvariantFailure]:
	var r: Variant = _call(hook, &"check", [world], &"")
	var out: Array[NpcfInvariantFailure] = []
	if r != null and _typed_array(r, out, hook, &""):
		return out
	return [NpcfInvariantFailure.make(invariant_id, tick, [] as Array[StringName], "hook_error")]


var _errored: bool = false


func _call(hook: Script, method: StringName, args: Array, npc: StringName) -> Variant:
	_errored = false
	var inst: RefCounted = instance(hook)
	if inst == null or not inst.has_method(method):
		_errored = true
		_fail(hook, npc, "cannot instantiate or has no method %s" % method)
		return null
	var before: int = _probe.script_errors
	var r: Variant = Callable(inst, method).callv(args)
	if _probe.script_errors != before:
		_errored = true
		_fail(hook, npc, "runtime error: " + _probe.last_message)
		return null
	return r


func _typed_array(r: Variant, out: Array, hook: Script, npc: StringName) -> bool:
	if not (r is Array):
		_fail(hook, npc, "returned %s, expected an array" % type_string(typeof(r)))
		return false
	var arr: Array = r
	for item: Variant in arr:
		if not is_instance_of(item, out.get_typed_script()):
			_fail(hook, npc, "returned an array with an element of the wrong type")
			return false
	out.assign(arr)
	return true


func _fail(hook: Script, npc: StringName, reason: String) -> void:
	var key: String = hook.resource_path
	failures[key] = failures.get(key, 0) + 1
	if log_failures:
		push_warning("npcf hook failure: pack=%s hook=%s npc=%s tick=%d reason=%s" % [_pack_namespace, key, npc, tick, reason])


## Total failures of one hook script.
func failure_count(hook: Script) -> int:
	return failures.get(hook.resource_path, 0)
