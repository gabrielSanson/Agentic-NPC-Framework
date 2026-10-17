class_name NpcfEffectApplier
extends RefCounted
## The only writer of facts, needs and tags (R5.2). Validates a batch of changes as a whole and
## applies them in order only when every change is valid. Also expands effect definitions into
## changes for one NPC.

## Handlers for kinds owned by later tasks: Callable(world, change, cause_event) -> String (error or "").
var rel_handler: Callable = Callable()
var share_handler: Callable = Callable()


## Applies a batch. Returns "" on success, or `changes[i]: reason` and changes nothing.
func apply(world: NpcfWorld, changes: Array[NpcfStateChange], cause_event: int, quiet: bool = false) -> String:
	for i: int in changes.size():
		var reason: String = validate(world, changes[i])
		if reason != "":
			return "changes[%d]: %s" % [i, reason]
	for c: NpcfStateChange in changes:
		_apply_one(world, c, cause_event, quiet)
	return ""


## Returns "" when `change` may be applied to the current state, else the reason.
func validate(world: NpcfWorld, change: NpcfStateChange) -> String:
	match change.kind:
		NpcfStateChange.Kind.SET_FACT:
			return _validate_fact(world, change, false)
		NpcfStateChange.Kind.ADD_FACT:
			return _validate_fact(world, change, true)
		NpcfStateChange.Kind.NEED_DELTA:
			var npc: NpcfNpcState = world.npc(change.subject)
			if npc == null:
				return "\"%s\" is not an NPC" % change.subject
			if not npc.needs.has(change.need):
				return "\"%s\" has no need \"%s\"" % [change.subject, change.need]
			return ""
		NpcfStateChange.Kind.TAG_ADD, NpcfStateChange.Kind.TAG_REMOVE:
			if world.npc(change.subject) == null:
				return "\"%s\" is not an NPC" % change.subject
			return ""
		NpcfStateChange.Kind.EMIT_EVENT:
			if change.event == null:
				return "EMIT_EVENT has no event"
			return world.events.validate(change.event)
		NpcfStateChange.Kind.REL_DELTA, NpcfStateChange.Kind.SHARE_BELIEFS:
			return ""
	return "unknown change kind %d" % change.kind


## Applies one NPC's need deltas in dictionary order, as NEED_DELTA changes with no events suppressed.
## The NPC and its needs are known to exist (the builder creates them), so nothing is validated.
func apply_need_deltas(world: NpcfWorld, npc: StringName, deltas: Dictionary[StringName, int]) -> void:
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return
	for need: StringName in deltas:
		var old: int = n.needs.get(need, 0)
		world.need_system.set_need(world, npc, need, old + deltas[need], false)


## Expands an action's effect definitions into changes for `npc`. Returns an Array[NpcfStateChange],
## or null when a HOOK effect failed (the caller then fails the action with hook_error).
static func expand(world: NpcfWorld, effects: Array[NpcfEffectDef], npc: StringName, args: Dictionary[StringName, Variant]) -> Variant:
	var out: Array[NpcfStateChange] = []
	for e: NpcfEffectDef in effects:
		if e == null:
			continue
		var subject: StringName = NpcfConditions.subject(world, npc, e.subject_from, e.arg, args)
		match e.kind:
			NpcfEffectDef.Kind.SET_FACT:
				if e.fact != null:
					out.append(NpcfStateChange.set_fact(subject, e.fact.id, e.value))
			NpcfEffectDef.Kind.ADD_FACT:
				if e.fact != null:
					out.append(NpcfStateChange.add_fact(subject, e.fact.id, e.amount))
			NpcfEffectDef.Kind.NEED_DELTA:
				if e.need != null:
					out.append(NpcfStateChange.need_delta(npc, e.need.id, e.amount))
			NpcfEffectDef.Kind.TAG_ADD:
				out.append(NpcfStateChange.tag_change(subject, e.tag, true))
			NpcfEffectDef.Kind.TAG_REMOVE:
				out.append(NpcfStateChange.tag_change(subject, e.tag, false))
			NpcfEffectDef.Kind.REL_DELTA, NpcfEffectDef.Kind.SHARE_BELIEFS:
				# Social effects are completed in task 17; the change carries the parties.
				var rc: NpcfStateChange = NpcfStateChange.new()
				rc.kind = NpcfStateChange.Kind.REL_DELTA if e.kind == NpcfEffectDef.Kind.REL_DELTA else NpcfStateChange.Kind.SHARE_BELIEFS
				rc.subject = npc
				rc.other = NpcfConditions.subject(world, npc, e.to_from, e.to_arg, args)
				rc.dim = e.dim
				rc.amount = e.amount
				out.append(rc)
			NpcfEffectDef.Kind.EMIT_EVENT:
				if e.event_kind != null:
					out.append(NpcfStateChange.emit_event(_event_for(world, npc, e, args)))
			NpcfEffectDef.Kind.HOOK:
				if e.hook == null:
					return null
				var merged: Dictionary[StringName, Variant] = e.hook_args.duplicate()
				merged.merge(args)
				var r: Variant = world.hooks.effect(e.hook, world.view(npc).as_truth(), merged)
				if r == null:
					return null
				var changes: Array[NpcfStateChange] = []
				var raw: Array = r
				changes.assign(raw)
				out.append_array(changes)
	return out


static func _event_for(world: NpcfWorld, npc: StringName, e: NpcfEffectDef, args: Dictionary[StringName, Variant]) -> NpcfEvent:
	var ev: NpcfEvent = NpcfEvent.new()
	ev.kind = e.event_kind.id
	ev.actors = [npc]
	ev.location = world.location_of(npc)
	var target: StringName = NpcfConditions.subject(world, npc, e.to_from, e.to_arg, args)
	if target != &"":
		ev.targets = [target]
	for fd: NpcfFieldDef in e.event_kind.payload_fields:
		if fd != null and args.has(fd.name):
			ev.payload[fd.name] = args[fd.name]
	return ev


func _validate_fact(world: NpcfWorld, change: NpcfStateChange, is_add: bool) -> String:
	var def: NpcfFactDef = world.state.fact_def(change.fact_id)
	if def == null:
		return "unknown fact \"%s\"" % change.fact_id
	if is_add:
		if def.value_type != NpcfFactDef.ValueType.INT and def.value_type != NpcfFactDef.ValueType.FLOAT:
			return "ADD_FACT needs an int or float fact, not %s" % change.fact_id
	else:
		if not def.accepts(change.value):
			return "value %s does not match type %s" % [str(change.value), NpcfFactDef.type_name(def.value_type)]
		if not def.in_bounds(change.value):
			return "value %s is outside %s..%s" % [str(change.value), def.min_value, def.max_value]
	match def.scope:
		NpcfFactDef.Scope.GLOBAL:
			if change.subject != NpcfFramework.GLOBAL:
				return "global fact subject must be \"npcf.global\", not \"%s\"" % change.subject
		NpcfFactDef.Scope.ENTITY:
			if not world.is_entity(change.subject):
				return "\"%s\" is not an entity" % change.subject
		NpcfFactDef.Scope.LOCATION:
			if not world.pack.location_index.has_location(change.subject):
				return "\"%s\" is not a location" % change.subject
	return ""


func _apply_one(world: NpcfWorld, c: NpcfStateChange, cause_event: int, quiet: bool) -> void:
	match c.kind:
		NpcfStateChange.Kind.SET_FACT:
			_set_fact(world, c.subject, c.fact_id, c.value, quiet)
		NpcfStateChange.Kind.ADD_FACT:
			_add_fact(world, c, quiet)
		NpcfStateChange.Kind.NEED_DELTA:
			var npc: NpcfNpcState = world.npc(c.subject)
			var old: int = npc.needs.get(c.need, 0)
			world.need_system.set_need(world, c.subject, c.need, old + c.amount, quiet)
		NpcfStateChange.Kind.TAG_ADD, NpcfStateChange.Kind.TAG_REMOVE:
			_change_tag(world, c, quiet)
		NpcfStateChange.Kind.EMIT_EVENT:
			world.emit(c.event)
		NpcfStateChange.Kind.REL_DELTA:
			if rel_handler.is_valid():
				rel_handler.call(world, c, cause_event)
		NpcfStateChange.Kind.SHARE_BELIEFS:
			if share_handler.is_valid():
				share_handler.call(world, c, cause_event)


func _add_fact(world: NpcfWorld, c: NpcfStateChange, quiet: bool) -> void:
	var def: NpcfFactDef = world.state.fact_def(c.fact_id)
	var old: Variant = world.state.get_fact(c.subject, c.fact_id)
	var next: Variant
	if def.value_type == NpcfFactDef.ValueType.INT:
		var oi: int = old
		var ni: int = oi + c.amount
		if def.bounded:
			ni = clampi(ni, int(def.min_value), int(def.max_value))
		next = ni
	else:
		var of: float = old
		var nf: float = of + float(c.amount)
		if def.bounded:
			nf = clampf(nf, def.min_value, def.max_value)
		next = nf
	_set_fact(world, c.subject, c.fact_id, next, quiet)


func _set_fact(world: NpcfWorld, subject: StringName, fact_id: StringName, value: Variant, quiet: bool) -> void:
	var def: NpcfFactDef = world.state.fact_def(fact_id)
	var old: Variant = world.state.get_fact(subject, fact_id)
	var changed: bool = old != value
	if fact_id == NpcfFramework.AT and world.npcs.has(subject):
		var from: StringName = world.location_of(subject)
		world.state.write(subject, fact_id, value)
		world.occupancy.move(subject, from, world.location_of(subject))
	else:
		world.state.write(subject, fact_id, value)
	if not changed or quiet or fact_id == NpcfFramework.AT:
		return
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = NpcfFramework.FACT_CHANGED
	e.payload = {&"subject": subject, &"fact": fact_id, &"value": value}
	match def.scope:
		NpcfFactDef.Scope.ENTITY:
			e.location = world.location_of(subject)
		NpcfFactDef.Scope.LOCATION:
			e.location = subject
	var id: int = world.emit(e)
	if id >= 0 and def.scope == NpcfFactDef.Scope.GLOBAL:
		e.visibility = NpcfEvent.Visibility.PUBLIC


func _change_tag(world: NpcfWorld, c: NpcfStateChange, quiet: bool) -> void:
	var npc: NpcfNpcState = world.npc(c.subject)
	var present: bool = npc.tags.has(c.tag)
	var add: bool = c.kind == NpcfStateChange.Kind.TAG_ADD
	if add == present:
		return
	if add:
		npc.tags.append(c.tag)
	else:
		npc.tags.erase(c.tag)
	if quiet:
		return
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = NpcfFramework.TAGS_CHANGED
	e.actors = [c.subject]
	e.location = world.location_of(c.subject)
	e.payload = {&"tag": c.tag, &"added": add}
	world.emit(e)
