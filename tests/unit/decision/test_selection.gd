extends GdUnitTestSuite
## Goal selection: ranking with ID tie-break, hysteresis, interrupts, bypass, unreachable cooldown,
## planning fallback, a busy NPC keeping its goal, and the decision record. Goals are inline, each with
## candidate action toy.rest (planned from home, where Bo and Ana rest) and no considerations, so a
## goal's utility is its weight. Bo starts at home_b; the goals carry no personality multipliers.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _goal(w: NpcfWorld, id: StringName, weight: float, action_ids: Array[StringName]) -> NpcfGoalDef:
	var g: NpcfGoalDef = NpcfGoalDef.new()
	g.id = id
	g.weight = weight
	var actions: Array[NpcfActionDef] = []
	for action_id: StringName in action_ids:
		actions.append(w.pack.action(action_id))
	g.candidate_actions = actions
	return g


## Gives Ana the goals (replacing her archetype goals) and returns her state.
func _set_goals(w: NpcfWorld, npc: StringName, goals: Array[NpcfGoalDef]) -> NpcfNpcState:
	var n: NpcfNpcState = w.npc(npc)
	n.resolved.goals.clear()
	for g: NpcfGoalDef in goals:
		n.resolved.goals.append(g)
	return n


func _rest_goal(w: NpcfWorld, id: StringName, weight: float) -> NpcfGoalDef:
	var actions: Array[StringName] = [&"toy.rest"]
	return _goal(w, id, weight, actions)


func test_equal_utility_breaks_the_tie_by_goal_id() -> void:
	var w: NpcfWorld = _world()
	_set_goals(w, &"toy.ana", [_rest_goal(w, &"x.b", 1.0), _rest_goal(w, &"x.a", 1.0)] as Array[NpcfGoalDef])
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_array(record.scores.map(func(s: NpcfScoredGoal) -> StringName: return s.goal)).is_equal([&"x.a", &"x.b"])
	assert_str(String(record.chosen_goal)).is_equal("x.a")


func test_hysteresis_keeps_the_current_goal_for_a_small_gain() -> void:
	var w: NpcfWorld = _world()
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [_rest_goal(w, &"x.a", 1.0), _rest_goal(w, &"x.b", 1.05)] as Array[NpcfGoalDef])
	n.current_goal = &"x.a"
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.chosen_goal)).is_equal("x.a")
	assert_bool(record.kept).is_true()
	assert_bool(record.hysteresis_blocked).is_true()
	assert_str(String(n.current_goal)).is_equal("x.a")


func test_a_gain_beyond_hysteresis_switches_the_goal() -> void:
	var w: NpcfWorld = _world()
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [_rest_goal(w, &"x.a", 1.0), _rest_goal(w, &"x.b", 1.2)] as Array[NpcfGoalDef])
	n.current_goal = &"x.a"
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.chosen_goal)).is_equal("x.b")
	assert_bool(record.kept).is_false()
	assert_bool(record.hysteresis_blocked).is_false()
	assert_str(String(record.previous_goal)).is_equal("x.a")


func test_an_interrupt_on_the_best_goal_bypasses_hysteresis() -> void:
	var w: NpcfWorld = _world()
	var b: NpcfGoalDef = _rest_goal(w, &"x.b", 1.05)
	var interrupt: NpcfConditionDef = NpcfConditionDef.new()
	interrupt.op_kind = NpcfConditionDef.OpKind.NEED
	interrupt.need = w.pack.need(&"toy.energy")
	interrupt.compare = NpcfConditionDef.Compare.GE
	interrupt.value = 0
	b.interrupt = interrupt
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [_rest_goal(w, &"x.a", 1.0), b] as Array[NpcfGoalDef])
	n.current_goal = &"x.a"
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.chosen_goal)).is_equal("x.b")
	assert_bool(record.interrupted).is_true()


func test_a_goal_in_unreachable_cooldown_is_skipped() -> void:
	var w: NpcfWorld = _world()
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [_rest_goal(w, &"x.a", 1.0), _rest_goal(w, &"x.b", 5.0)] as Array[NpcfGoalDef])
	n.unreachable_until[&"x.b"] = w.clock.tick + 10
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.chosen_goal)).is_equal("x.a")
	assert_int(record.rejected.size()).is_equal(1)
	if record.rejected.size() == 1:
		assert_str(String(record.rejected[0].goal)).is_equal("x.b")
		assert_str(String(record.rejected[0].reason)).is_equal("unreachable_cooldown")


func test_a_goal_without_a_plan_cools_down_and_the_next_is_planned() -> void:
	var w: NpcfWorld = _world()
	var action: NpcfActionDef = NpcfActionDef.new()
	action.id = &"toy.nowhere_action"
	action.duration_ticks = 1
	action.required_location_tag = &"toy.no_such_tag"
	w.pack.actions[action.id] = action
	var nowhere: NpcfGoalDef = _goal(w, &"x.nowhere", 9.0, [&"toy.nowhere_action"] as Array[StringName])
	nowhere.unreachable_cooldown_ticks = 25
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [nowhere, _rest_goal(w, &"x.a", 1.0)] as Array[NpcfGoalDef])
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.chosen_goal)).is_equal("x.a")
	assert_int(n.unreachable_until.get(&"x.nowhere", 0)).is_equal(w.clock.tick + 25)
	var reasons: Array[String] = []
	for r: NpcfRejectedGoal in record.rejected:
		reasons.append("%s:%s" % [r.goal, r.reason])
	assert_array(reasons).is_equal(["x.nowhere:no_plan"])


func test_busy_npc_keeps_its_goal_and_starts_nothing_new() -> void:
	var w: NpcfWorld = _world()
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [_rest_goal(w, &"x.a", 1.0), _rest_goal(w, &"x.b", 1.0)] as Array[NpcfGoalDef])
	n.current_goal = &"x.a"
	var first: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(first.chosen_goal)).is_equal("x.a")
	var running: NpcfRunningAction = n.running
	assert_object(running).is_not_null()
	var second: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(second.chosen_goal)).is_equal("x.a")
	assert_bool(second.kept).is_true()
	assert_array(second.plan).is_empty()
	assert_object(n.running).is_same(running)


func test_no_goal_with_utility_clears_the_current_goal() -> void:
	var w: NpcfWorld = _world()
	var zero: NpcfGoalDef = _goal(w, &"x.zero", 0.0, [&"toy.rest"] as Array[StringName])
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [zero] as Array[NpcfGoalDef])
	n.current_goal = &"x.zero"
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.chosen_goal)).is_equal("")
	assert_str(String(n.current_goal)).is_equal("")


func test_record_is_filled_and_kept_in_the_ring_buffer() -> void:
	var w: NpcfWorld = _world()
	var n: NpcfNpcState = _set_goals(w, &"toy.ana", [_rest_goal(w, &"x.a", 1.0)] as Array[NpcfGoalDef])
	n.current_goal = &"x.old"
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_int(record.tick).is_equal(w.clock.tick)
	assert_str(String(record.npc)).is_equal("toy.ana")
	assert_str(String(record.previous_goal)).is_equal("x.old")
	assert_str(String(record.chosen_goal)).is_equal("x.a")
	assert_array(record.plan).is_equal([&"toy.rest"])
	assert_str(String(record.start_result)).is_equal("ok")
	assert_int(record.scores.size()).is_equal(1)
	assert_int(n.decision_records.size()).is_equal(1)
	var d: Dictionary = record.to_dict()
	var chosen: String = d["chosen_goal"]
	assert_str(chosen).is_equal("x.a")
	var plan: Array[String] = d["plan"]
	assert_array(plan).is_equal(["toy.rest"])
