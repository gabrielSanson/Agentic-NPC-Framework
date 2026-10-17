class_name NpcfExecutor
extends RefCounted
## Starts, advances, finishes and cancels actions (R9.3-R9.6). Services take the world on every call.
## Start reasons, checked in order: busy, stale, unknown_action, bad_args, cooldown, precondition_failed,
## wrong_location, unreachable (npcf.move_to only), effect_failed. An unknown NPC gives unknown_npc.

const OK: StringName = &"ok"


## Checks a call and starts it. Returns OK, or the reason it was refused.
func start(world: NpcfWorld, npc: StringName, call: NpcfActionCall, report: NpcfTickReport = null) -> StringName:
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return &"unknown_npc"
	if n.is_busy():
		return &"busy"
	var tick: int = world.clock.tick
	if tick - call.decision_tick > world.sim.staleness_limit_ticks:
		return &"stale"
	var def: NpcfActionDef = world.pack.action(call.action)
	if def == null:
		return &"unknown_action"
	if NpcfFieldDef.validate(def.args, call.args) != "":
		return &"bad_args"
	var cooldown_until: int = n.cooldowns.get(def.id, 0)
	if cooldown_until > tick:
		return &"cooldown"

	var truth: NpcfNpcView = world.view(npc).as_truth()
	var belief: NpcfNpcView = world.view(npc)
	var failed: bool = false
	for c: NpcfConditionDef in def.preconditions:
		if not NpcfConditions.check(world, truth, c, call.args, false):
			failed = true
	if failed:
		for c: NpcfConditionDef in def.preconditions:
			for f: NpcfFact in NpcfConditions.mismatched_facts(world, belief, truth, c, call.args):
				_emit_expectation(world, npc, f)
		return &"precondition_failed"

	var here: StringName = world.location_of(npc)
	if def.required_location != null and here != def.required_location.id:
		return &"wrong_location"
	if def.required_location_tag != &"" and not world.pack.location_index.has_tag(here, def.required_location_tag):
		return &"wrong_location"

	var is_move: bool = def.id == NpcfFramework.MOVE_TO
	var path: NpcfPath = null
	if is_move:
		var target: StringName = call.args.get(&"location", &"")
		path = world.pack.location_index.path(here, target)
		if path == null:
			return &"unreachable"

	if _apply_effects(world, def.start_effects, npc, call.args) != "":
		return &"effect_failed"

	call.call_id = world.next_call_id
	world.next_call_id += 1
	var ra: NpcfRunningAction = NpcfRunningAction.new()
	ra.call = call
	ra.def = def
	ra.started_tick = tick
	ra.timeout = def.effective_timeout()
	if is_move:
		ra.timeout = 2 * path.ticks + 30
		ra.path.assign(path.nodes)
		ra.last_location = here
	n.running = ra
	if def.cooldown_ticks > 0:
		n.cooldowns[def.id] = tick + def.cooldown_ticks
	ra.embodied = world.adapters.movement.is_embodied(npc)
	if is_move:
		if ra.embodied:
			world.adapters.movement.move_along(npc, call.call_id, ra.path)
	else:
		world.adapters.presentation.play(npc, NpcfActionCallView.new(call, def))

	var o: NpcfActionOutcome = _outcome(world, n, ra, &"started")
	if report != null:
		report.started.append(o)
	_remember(world, n, o)
	return OK


## Moves every running action one tick forward and finishes the ones that are done or timed out.
func advance(world: NpcfWorld, report: NpcfTickReport = null) -> void:
	for id: StringName in world.npc_ids:
		var n: NpcfNpcState = world.npc(id)
		if n == null or not n.is_busy():
			continue
		var ra: NpcfRunningAction = n.running
		ra.elapsed += 1
		var status: int = NpcfResolverHook.RUNNING
		var is_move: bool = ra.call.action == NpcfFramework.MOVE_TO
		if is_move:
			if not ra.embodied:
				status = world.travel.step(world, id, ra)
				if status == NpcfResolverHook.FAILURE:
					finish(world, id, false, &"move_failed", report)
					continue
		elif not ra.embodied:
			if ra.def.resolver != null:
				var view: NpcfActionCallView = NpcfActionCallView.new(ra.call, ra.def)
				status = world.hooks.resolver(ra.def.resolver, view, world.world_view(), ra.elapsed)
			elif ra.elapsed >= ra.def.duration_ticks:
				status = NpcfResolverHook.SUCCESS
		if status == NpcfResolverHook.SUCCESS:
			finish(world, id, true, &"success", report)
		elif status == NpcfResolverHook.FAILURE:
			finish(world, id, false, &"resolver_failed", report)
		elif ra.elapsed >= ra.timeout:
			finish(world, id, false, &"timeout", report)


## Ends the NPC's running action. Runs the end effects on success and the cleanup effects otherwise,
## exactly one of them. A failing end effect counts as a failure. No-op when nothing is running.
func finish(world: NpcfWorld, npc: StringName, success: bool, reason: StringName, report: NpcfTickReport = null) -> void:
	var n: NpcfNpcState = world.npc(npc)
	if n == null or n.running == null:
		return
	var ra: NpcfRunningAction = n.running
	if ra.finished:
		return
	ra.finished = true
	var ok: bool = success
	var why: StringName = reason
	if ok:
		if _apply_effects(world, ra.def.end_effects, npc, ra.call.args) != "":
			ok = false
			why = &"effect_failed"
	if not ok:
		var cleanup_error: String = _apply_effects(world, ra.def.cleanup_effects, npc, ra.call.args)
		if cleanup_error != "":
			push_warning("npcf: cleanup of %s failed: %s" % [ra.def.id, cleanup_error])
	var outcome: StringName = &"success" if ok else why
	var o: NpcfActionOutcome = _outcome(world, n, ra, outcome)
	if report != null:
		report.finished.append(o)
	_remember(world, n, o)
	if not ok and ra.embodied:
		world.adapters.presentation.cancel(npc, ra.call.call_id)
		world.adapters.movement.stop(npc)

	if ok and not n.plan.is_empty():
		var next: NpcfActionCall = n.plan.pop_front()
		next.decision_tick = world.clock.tick
		if start(world, npc, next, report) != OK:
			n.plan.clear()
			n.running = null
			world.scheduler.mark_due(world, npc, &"plan_step_failed", false)
		return
	n.running = null
	n.plan.clear()
	world.scheduler.mark_due(world, npc, &"action_end" if ok else &"action_failed", false)


## Cancels the NPC's plan and its running action. Cleanup runs once, even on the start tick.
func cancel(world: NpcfWorld, npc: StringName, reason: StringName, report: NpcfTickReport = null) -> void:
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return
	n.plan.clear()
	finish(world, npc, false, reason, report)


## The game reported that a presentation finished. Ignored unless the call ID is the running one.
func on_finished(world: NpcfWorld, input: NpcfInput) -> void:
	var n: NpcfNpcState = world.npc(input.npc)
	if n == null or n.running == null or n.running.call.call_id != input.call_id:
		return
	if input.success:
		finish(world, input.npc, true, &"success")
	else:
		var why: StringName = input.reason if input.reason != &"" else &"failed"
		finish(world, input.npc, false, why)


## The movement adapter could not walk the path. Fails the move and cools the current goal down.
func on_move_failed(world: NpcfWorld, input: NpcfInput) -> void:
	var n: NpcfNpcState = world.npc(input.npc)
	if n == null or n.running == null or n.running.call.call_id != input.call_id:
		return
	if n.current_goal != &"":
		var goal: NpcfGoalDef = world.pack.goal(n.current_goal)
		if goal != null:
			n.unreachable_until[goal.id] = world.clock.tick + goal.unreachable_cooldown_ticks
	var why: StringName = input.reason if input.reason != &"" else &"move_failed"
	finish(world, input.npc, false, why)


## Starts a planned sequence: the first step now, the rest queued. Returns the first step's result.
func start_plan(world: NpcfWorld, npc: StringName, plan: NpcfPlan, report: NpcfTickReport = null) -> StringName:
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return &"unknown_npc"
	if plan == null or plan.steps.is_empty():
		return &"empty_plan"
	if n.is_busy():
		return &"busy"
	n.plan.clear()
	for i: int in range(1, plan.steps.size()):
		n.plan.append(plan.steps[i])
	var result: StringName = start(world, npc, plan.steps[0], report)
	if result != OK:
		n.plan.clear()
	return result


## Runs an effect list for an NPC as one batch. Returns "" on success or the reason.
func _apply_effects(world: NpcfWorld, effects: Array[NpcfEffectDef], npc: StringName, args: Dictionary[StringName, Variant]) -> String:
	var raw: Variant = NpcfEffectApplier.expand(world, effects, npc, args)
	if raw == null:
		return "a hook effect failed"
	var arr: Array = raw
	var changes: Array[NpcfStateChange] = []
	changes.assign(arr)
	return world.applier.apply(world, changes, -1)


## Reports a precondition that the NPC's belief got wrong. The payload carries the true value.
func _emit_expectation(world: NpcfWorld, npc: StringName, f: NpcfFact) -> void:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = NpcfFramework.EXPECTATION_FAILED
	e.actors = [npc]
	e.location = world.location_of(npc)
	e.payload = {&"subject": f.subject, &"fact": f.fact_id, &"value": f.value}
	world.emit(e)


func _outcome(world: NpcfWorld, n: NpcfNpcState, ra: NpcfRunningAction, outcome: StringName) -> NpcfActionOutcome:
	var o: NpcfActionOutcome = NpcfActionOutcome.new()
	o.npc = n.id
	o.action = ra.call.action
	o.call_id = ra.call.call_id
	o.tick = world.clock.tick
	o.started_tick = ra.started_tick
	o.outcome = outcome
	o.location = world.location_of(n.id)
	return o


## Keeps the NPC's most recent outcomes, up to the sim's decision_records.
func _remember(world: NpcfWorld, n: NpcfNpcState, o: NpcfActionOutcome) -> void:
	n.action_outcomes.append(o)
	var cap: int = maxi(1, world.sim.decision_records)
	while n.action_outcomes.size() > cap:
		n.action_outcomes.pop_front()
