extends GdUnitTestSuite
## The executor: every start reason code, expectation_failed, start and per-tick effects, end and
## cleanup effects (success, failure, timeout, cancel, start-tick cancel, end-effect failure), resolver
## hook statuses, and plan chaining. Ana starts at home_a, Cy at home_a, Bo at home_b.

const OK_RESOLVER: String = "res://tests/fixtures/hooks/ok_resolver.gd"
const BAD_STATUS: String = "res://tests/fixtures/hooks/bad_status_resolver.gd"
const ERROR_RESOLVER: String = "res://tests/fixtures/hooks/error_resolver.gd"

var _worlds: Array[NpcfWorld] = []
var _report: NpcfTickReport = null


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world() -> NpcfWorld:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var mood: NpcfFactDef = NpcfFactDef.new()
	mood.id = &"toy.mood"
	mood.scope = NpcfFactDef.Scope.ENTITY
	mood.value_type = NpcfFactDef.ValueType.BOOL
	mood.default_value = false
	mood.public = false
	pack.facts[mood.id] = mood
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), 1)
	_worlds.append(w)
	_report = NpcfTickReport.new()
	return w


func _call(w: NpcfWorld, npc: StringName, action: StringName, args: Dictionary[StringName, Variant] = {}) -> NpcfActionCall:
	return NpcfActionCall.make(npc, action, args, w.clock.tick)


## Registers an action with the given duration and effect lists, and returns it.
func _action(w: NpcfWorld, id: StringName, duration: int, start_fx: Array[NpcfEffectDef] = [],
		end_fx: Array[NpcfEffectDef] = [], cleanup_fx: Array[NpcfEffectDef] = []) -> NpcfActionDef:
	var a: NpcfActionDef = NpcfActionDef.new()
	a.id = id
	a.duration_ticks = duration
	a.start_effects = start_fx
	a.end_effects = end_fx
	a.cleanup_effects = cleanup_fx
	w.pack.actions[id] = a
	return a


func _add(w: NpcfWorld, amount: int) -> NpcfEffectDef:
	var e: NpcfEffectDef = NpcfEffectDef.new()
	e.kind = NpcfEffectDef.Kind.ADD_FACT
	e.subject_from = NpcfConditionDef.SubjectFrom.GLOBAL
	e.fact = w.pack.fact(&"toy.discoveries")
	e.amount = amount
	return e


func _set_discoveries(w: NpcfWorld, value: int) -> NpcfEffectDef:
	var e: NpcfEffectDef = NpcfEffectDef.new()
	e.kind = NpcfEffectDef.Kind.SET_FACT
	e.subject_from = NpcfConditionDef.SubjectFrom.GLOBAL
	e.fact = w.pack.fact(&"toy.discoveries")
	e.value = value
	return e


func _discoveries(w: NpcfWorld) -> int:
	return w.state.get_fact(&"npcf.global", &"toy.discoveries")


func _tick(w: NpcfWorld, n: int) -> void:
	for _i: int in n:
		w.clock.advance()
		w.executor.advance(w, _report)


func _last_outcome(w: NpcfWorld, npc: StringName) -> StringName:
	var list: Array[NpcfActionOutcome] = w.npc(npc).action_outcomes
	return list.back().outcome if not list.is_empty() else &""


# --- start reason codes ------------------------------------------------------------------------

func test_start_succeeds_for_a_legal_call() -> void:
	var w: NpcfWorld = _world()
	var call: NpcfActionCall = _call(w, &"toy.ana", &"toy.rest")
	assert_str(String(w.executor.start(w, &"toy.ana", call, _report))).is_equal("ok")
	assert_int(call.call_id).is_equal(1)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	assert_int(_report.started.size()).is_equal(1)


func test_busy_when_the_npc_already_runs_an_action() -> void:
	var w: NpcfWorld = _world()
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.rest"), _report)
	var second: StringName = w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.rest"), _report)
	assert_str(String(second)).is_equal("busy")


func test_stale_when_decided_too_long_ago() -> void:
	var w: NpcfWorld = _world()
	var call: NpcfActionCall = _call(w, &"toy.ana", &"toy.rest")
	for _i: int in 6:
		w.clock.advance()
	assert_str(String(w.executor.start(w, &"toy.ana", call, _report))).is_equal("stale")


func test_unknown_action() -> void:
	var w: NpcfWorld = _world()
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.nope"), _report))).is_equal("unknown_action")


func test_bad_args_for_unexpected_or_missing_arguments() -> void:
	var w: NpcfWorld = _world()
	var args: Dictionary[StringName, Variant] = {&"speed": 3}
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.rest", args), _report))).is_equal("bad_args")
	var missing: Dictionary[StringName, Variant] = {}
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", NpcfFramework.MOVE_TO, missing), _report))).is_equal("bad_args")


func test_cooldown_after_a_finished_action() -> void:
	var w: NpcfWorld = _world()
	var nap: NpcfActionDef = _action(w, &"toy.nap", 1)
	nap.cooldown_ticks = 10
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.nap"), _report))).is_equal("ok")
	w.executor.cancel(w, &"toy.ana", &"cancelled", _report)
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.nap"), _report))).is_equal("cooldown")


func test_precondition_failed_at_night() -> void:
	var w: NpcfWorld = _world()
	w.clock.start_minute = 60
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.chat"), _report))).is_equal("precondition_failed")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()


func test_wrong_location_for_a_required_location_and_a_tag() -> void:
	var w: NpcfWorld = _world()
	# Work needs the workshop, rest needs a home tag; Ana is at home_a.
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.work"), _report))).is_equal("wrong_location")
	w.applier.apply(w, [NpcfStateChange.set_fact(&"toy.ana", NpcfFramework.AT, &"toy.yard")] as Array[NpcfStateChange], -1, true)
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.rest"), _report))).is_equal("wrong_location")


func test_unreachable_move_target() -> void:
	var w: NpcfWorld = _world()
	var args: Dictionary[StringName, Variant] = {&"location": &"toy.nowhere"}
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", NpcfFramework.MOVE_TO, args), _report))).is_equal("unreachable")


func test_effect_failed_when_a_start_effect_is_invalid() -> void:
	var w: NpcfWorld = _world()
	var fx: Array[NpcfEffectDef] = [_set_discoveries(w, -1)]
	_action(w, &"toy.bad_start", 1, fx)
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.bad_start"), _report))).is_equal("effect_failed")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()


func _expectations(w: NpcfWorld) -> Array[NpcfEvent]:
	var out: Array[NpcfEvent] = []
	for e: NpcfEvent in w.events.log:
		if e.kind == NpcfFramework.EXPECTATION_FAILED:
			out.append(e)
	return out


func test_expectation_failed_when_the_belief_was_wrong_and_is_corrected() -> void:
	var w: NpcfWorld = _world()
	var cond: NpcfConditionDef = NpcfConditionDef.new()
	cond.op_kind = NpcfConditionDef.OpKind.FACT
	cond.subject_from = NpcfConditionDef.SubjectFrom.PLAYER
	cond.fact = w.pack.fact(&"toy.mood")
	cond.compare = NpcfConditionDef.Compare.EQ
	cond.value = true
	var gate: NpcfActionDef = _action(w, &"toy.gate", 1)
	gate.preconditions = [cond] as Array[NpcfConditionDef]
	# Truth: the player is not in a good mood. Ana believes that they are.
	var wrong: NpcfBeliefMeta = NpcfBeliefMeta.new()
	wrong.tick = 0
	wrong.confidence = 100
	w.npc(&"toy.ana").beliefs.put(NpcfFact.make(&"toy.player", &"toy.mood", true), wrong)
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.gate"), _report))).is_equal("precondition_failed")
	var reported: Array[NpcfEvent] = _expectations(w)
	assert_int(reported.size()).is_equal(1)
	if reported.size() == 1:
		assert_array(reported[0].actors).is_equal([&"toy.ana"])
		assert_bool(reported[0].payload[&"value"]).is_false()
	# Delivery corrects the belief: the same refusal is no longer a surprise, so nothing is reported again.
	var fixed: NpcfBeliefMeta = NpcfBeliefMeta.new()
	fixed.tick = 1
	fixed.confidence = 100
	w.npc(&"toy.ana").beliefs.put(NpcfFact.make(&"toy.player", &"toy.mood", false), fixed)
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.gate"), _report))).is_equal("precondition_failed")
	assert_int(_expectations(w).size()).is_equal(1)
	# Once the world matches the precondition, the action starts.
	w.applier.apply(w, [NpcfStateChange.set_fact(&"toy.player", &"toy.mood", true)] as Array[NpcfStateChange], -1, true)
	assert_str(String(w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.gate"), _report))).is_equal("ok")


# --- effects and outcomes ------------------------------------------------------------------------

func test_start_effects_apply_at_start() -> void:
	var w: NpcfWorld = _world()
	var fx: Array[NpcfEffectDef] = [_add(w, 1)]
	_action(w, &"toy.begin", 5, fx)
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.begin"), _report)
	assert_int(_discoveries(w)).is_equal(1)


func test_per_tick_need_deltas_apply_while_running() -> void:
	var w: NpcfWorld = _world()
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.rest"), _report)
	w.need_system.tick(w)
	assert_int(w.npc(&"toy.ana").needs[&"toy.energy"]).is_equal(705)


func test_end_effects_run_on_success() -> void:
	var w: NpcfWorld = _world()
	var end: Array[NpcfEffectDef] = [_add(w, 5)]
	_action(w, &"toy.finish_me", 2, [] as Array[NpcfEffectDef], end)
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.finish_me"), _report)
	_tick(w, 1)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	_tick(w, 1)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_int(_discoveries(w)).is_equal(5)
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("success")
	assert_int(_report.finished.size()).is_equal(1)


func test_cleanup_runs_on_failure_and_end_does_not() -> void:
	var w: NpcfWorld = _world()
	var end: Array[NpcfEffectDef] = [_add(w, 100)]
	var cleanup: Array[NpcfEffectDef] = [_add(w, 1)]
	_action(w, &"toy.stop_me", 10, [] as Array[NpcfEffectDef], end, cleanup)
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.stop_me"), _report)
	w.npc(&"toy.ana").running.timeout = 3
	_tick(w, 3)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_int(_discoveries(w)).is_equal(1)
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("timeout")


func test_cancel_runs_cleanup_once_even_on_the_start_tick() -> void:
	var w: NpcfWorld = _world()
	var cleanup: Array[NpcfEffectDef] = [_add(w, 1)]
	_action(w, &"toy.undo", 10, [] as Array[NpcfEffectDef], [] as Array[NpcfEffectDef], cleanup)
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.undo"), _report)
	w.executor.cancel(w, &"toy.ana", &"goal_switch", _report)
	w.executor.cancel(w, &"toy.ana", &"goal_switch", _report)
	assert_int(_discoveries(w)).is_equal(1)
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("goal_switch")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()


func test_end_effect_failure_runs_cleanup_instead() -> void:
	var w: NpcfWorld = _world()
	var end: Array[NpcfEffectDef] = [_set_discoveries(w, -1)]
	var cleanup: Array[NpcfEffectDef] = [_add(w, 1)]
	_action(w, &"toy.broken_end", 1, [] as Array[NpcfEffectDef], end, cleanup)
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.broken_end"), _report)
	_tick(w, 1)
	assert_int(_discoveries(w)).is_equal(1)
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("effect_failed")


func test_resolver_hook_drives_the_outcome() -> void:
	var w: NpcfWorld = _world()
	var ok: NpcfActionDef = _action(w, &"toy.judged", 1)
	ok.resolver = load(OK_RESOLVER) as Script
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.judged"), _report)
	_tick(w, 2)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	_tick(w, 1)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("success")


func test_resolver_failure_and_invalid_status_both_fail_the_action() -> void:
	var w: NpcfWorld = _world()
	var bad: NpcfActionDef = _action(w, &"toy.invalid", 1)
	bad.resolver = load(BAD_STATUS) as Script
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.invalid"), _report)
	_tick(w, 1)
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("resolver_failed")


func test_runtime_error_in_a_resolver_fails_the_action() -> void:
	var w: NpcfWorld = _world()
	var crash: NpcfActionDef = _action(w, &"toy.crash", 1)
	crash.resolver = load(ERROR_RESOLVER) as Script
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.crash"), _report)
	await assert_error(func() -> void: w.executor.advance(w, _report)).is_runtime_error("Invalid call. Nonexistent function 'call_id' in base 'Nil'.")
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("resolver_failed")


func test_timeout_fails_a_running_action() -> void:
	var w: NpcfWorld = _world()
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.rest"), _report)
	var ra: NpcfRunningAction = w.npc(&"toy.ana").running
	ra.timeout = 4
	_tick(w, 4)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("timeout")


# --- plans ---------------------------------------------------------------------------------------

func test_plan_steps_run_in_order() -> void:
	var w: NpcfWorld = _world()
	_action(w, &"toy.one", 1)
	_action(w, &"toy.two", 1)
	var plan: NpcfPlan = NpcfPlan.new()
	plan.steps = [_call(w, &"toy.ana", &"toy.one"), _call(w, &"toy.ana", &"toy.two")] as Array[NpcfActionCall]
	assert_str(String(w.executor.start_plan(w, &"toy.ana", plan, _report))).is_equal("ok")
	_tick(w, 1)
	assert_str(String(w.npc(&"toy.ana").running.call.action)).is_equal("toy.two")
	_tick(w, 1)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_array(w.npc(&"toy.ana").plan).is_empty()


func test_failing_plan_step_clears_the_rest_of_the_plan() -> void:
	var w: NpcfWorld = _world()
	var fail: NpcfActionDef = _action(w, &"toy.fail", 1)
	fail.resolver = load(BAD_STATUS) as Script
	_action(w, &"toy.later", 1)
	var plan: NpcfPlan = NpcfPlan.new()
	plan.steps = [_call(w, &"toy.ana", &"toy.fail"), _call(w, &"toy.ana", &"toy.later")] as Array[NpcfActionCall]
	w.executor.start_plan(w, &"toy.ana", plan, _report)
	_tick(w, 1)
	assert_array(w.npc(&"toy.ana").plan).is_empty()
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()


# --- embodied completion (game-held or by duration) ---------------------------------------------

class EmbodiedMovement extends NpcfMovementAdapter:
	func is_embodied(_npc: StringName) -> bool:
		return true


class HoldingPresentation extends NpcfPresentationAdapter:
	var holds: bool = false

	func holds_completion(_npc: StringName, _call: NpcfActionCallView) -> bool:
		return holds


## Makes ana embodied, with a presentation that does or does not hold completion.
func _embodied(w: NpcfWorld, holds: bool) -> void:
	var p: HoldingPresentation = HoldingPresentation.new()
	p.holds = holds
	w.adapters = NpcfAdapterSet.make(EmbodiedMovement.new(), w.adapters.perception, p)


func test_embodied_action_without_a_hold_finishes_by_duration() -> void:
	var w: NpcfWorld = _world()
	_embodied(w, false)
	_action(w, &"toy.embodied", 3)
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.embodied"), _report)
	_tick(w, 2)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	_tick(w, 1)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("success")


func test_embodied_action_with_a_hold_runs_until_the_game_finishes_it() -> void:
	var w: NpcfWorld = _world()
	_embodied(w, true)
	_action(w, &"toy.embodied", 3)
	var call: NpcfActionCall = _call(w, &"toy.ana", &"toy.embodied")
	w.executor.start(w, &"toy.ana", call, _report)
	_tick(w, 10)  # well past the duration: nothing finishes it
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	w.executor.on_finished(w, NpcfInput.action_finished(&"toy.ana", call.call_id + 1, true))
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()  # a stale call ID is ignored
	w.executor.on_finished(w, NpcfInput.action_finished(&"toy.ana", call.call_id, true))
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("success")


func test_embodied_action_with_a_hold_still_times_out() -> void:
	var w: NpcfWorld = _world()
	_embodied(w, true)
	var def: NpcfActionDef = _action(w, &"toy.embodied", 3)
	w.executor.start(w, &"toy.ana", _call(w, &"toy.ana", &"toy.embodied"), _report)
	_tick(w, def.effective_timeout())
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(String(_last_outcome(w, &"toy.ana"))).is_equal("timeout")
