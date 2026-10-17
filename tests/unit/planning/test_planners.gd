extends GdUnitTestSuite
## Planners: the single-step move prefix (nearest tagged location, ID tie-break, no prefix when already
## there), the script planner (steps in order with prefixes), unplannable goals and the planning
## fallback, and revalidation of a later script step (a plan is dropped and the NPC becomes due).
## Ana starts at home_a and Bo at home_b unless a test moves them.

var _worlds: Array[NpcfWorld] = []
var _report: NpcfTickReport = null


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	_report = NpcfTickReport.new()
	return w


func _place(w: NpcfWorld, npc: StringName, at: StringName) -> void:
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(npc, NpcfFramework.AT, at)]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")


func _kinds(plan: NpcfPlan) -> Array[String]:
	var out: Array[String] = []
	for call: NpcfActionCall in plan.steps:
		out.append(String(call.action))
	return out


func _move_target(call: NpcfActionCall) -> String:
	var loc: StringName = call.args.get(&"location", &"")
	return String(loc)


func _tick(w: NpcfWorld, n: int) -> void:
	for _i: int in n:
		w.clock.advance()
		w.executor.advance(w, _report)
		w.delivery.deliver_pending(w)


# --- single-step move prefix ------------------------------------------------------------------

func test_move_prefix_goes_to_the_nearest_tagged_location() -> void:
	var w: NpcfWorld = _world()
	_place(w, &"toy.ana", &"toy.yard")
	var plan: NpcfPlan = NpcfPlanning.plan_for(w, &"toy.ana", w.pack.goal(&"toy.rest"))
	assert_str(String(plan.planner)).is_equal("npcf.single_step")
	assert_array(_kinds(plan)).is_equal(["npcf.move_to", "toy.rest"])
	assert_str(_move_target(plan.steps[0])).is_equal("toy.home_a")
	assert_int(plan.steps[0].decision_tick).is_equal(w.clock.tick)
	assert_str(String(plan.steps[0].npc)).is_equal("toy.ana")


func test_equal_distances_break_the_tie_by_location_id() -> void:
	var w: NpcfWorld = _world()
	var graph: NpcfLocationGraph = NpcfLocationGraph.new()
	var home_a: NpcfLocationDef = _location(&"toy.home_a", &"toy.home")
	var home_b: NpcfLocationDef = _location(&"toy.home_b", &"toy.home")
	var yard: NpcfLocationDef = _location(&"toy.yard", &"toy.outdoors")
	graph.locations = [home_b, yard, home_a]
	graph.edges = [_edge(home_a, yard, 5), _edge(home_b, yard, 5)]
	w.pack.location_index = NpcfLocationIndex.new(graph)
	_place(w, &"toy.ana", &"toy.yard")
	var plan: NpcfPlan = NpcfPlanning.plan_for(w, &"toy.ana", w.pack.goal(&"toy.rest"))
	assert_str(_move_target(plan.steps[0])).is_equal("toy.home_a")


func test_no_prefix_when_already_at_the_required_place() -> void:
	var w: NpcfWorld = _world()
	var plan: NpcfPlan = NpcfPlanning.plan_for(w, &"toy.bo", w.pack.goal(&"toy.rest"))
	assert_array(_kinds(plan)).is_equal(["toy.rest"])


func test_a_goal_with_no_reachable_place_has_no_plan() -> void:
	var w: NpcfWorld = _world()
	var action: NpcfActionDef = NpcfActionDef.new()
	action.id = &"toy.nowhere_action"
	action.duration_ticks = 1
	action.required_location_tag = &"toy.no_such_tag"
	w.pack.actions[action.id] = action
	var goal: NpcfGoalDef = NpcfGoalDef.new()
	goal.id = &"toy.nowhere"
	goal.candidate_actions = [action] as Array[NpcfActionDef]
	assert_object(NpcfPlanning.plan_for(w, &"toy.ana", goal)).is_null()


func test_unplannable_goal_cools_down_and_the_next_goal_is_planned() -> void:
	var w: NpcfWorld = _world()
	var action: NpcfActionDef = NpcfActionDef.new()
	action.id = &"toy.nowhere_action"
	action.duration_ticks = 1
	action.required_location_tag = &"toy.no_such_tag"
	w.pack.actions[action.id] = action
	var nowhere: NpcfGoalDef = NpcfGoalDef.new()
	nowhere.id = &"toy.nowhere"
	nowhere.weight = 9.0
	nowhere.candidate_actions = [action] as Array[NpcfActionDef]
	var n: NpcfNpcState = w.npc(&"toy.ana")
	n.resolved.goals.clear()
	n.resolved.goals.append(nowhere)
	n.resolved.goals.append(w.pack.goal(&"toy.explore"))
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.chosen_goal)).is_equal("toy.explore")
	assert_int(n.unreachable_until.get(&"toy.nowhere", 0)).is_equal(w.clock.tick + nowhere.unreachable_cooldown_ticks)


# --- script planner ----------------------------------------------------------------------------

func _script_goal(w: NpcfWorld, steps: Array[NpcfScriptStep]) -> NpcfGoalDef:
	var script: NpcfScriptDef = NpcfScriptDef.new()
	script.steps = steps
	var goal: NpcfGoalDef = NpcfGoalDef.new()
	goal.id = &"toy.script"
	goal.script_steps = script
	goal.candidate_actions = []
	return goal


func _step(w: NpcfWorld, action_id: StringName) -> NpcfScriptStep:
	var s: NpcfScriptStep = NpcfScriptStep.new()
	s.action = w.pack.action(action_id)
	return s


func test_script_steps_run_in_order_with_their_move_prefixes() -> void:
	var w: NpcfWorld = _world()
	var n: NpcfNpcState = w.npc(&"toy.ana")
	var ref: NpcfPlannerRef = NpcfPlannerRef.new()
	ref.kind = NpcfPlannerRef.Kind.SCRIPT
	n.resolved.planner = ref
	var steps: Array[NpcfScriptStep] = [_step(w, &"toy.explore"), _step(w, &"toy.rest")]
	var plan: NpcfPlan = NpcfPlanning.plan_for(w, &"toy.ana", _script_goal(w, steps))
	assert_str(String(plan.planner)).is_equal("npcf.script")
	# Explore needs the yard (5 from home_a); rest then needs a home again, nearest from the yard: home_a.
	assert_array(_kinds(plan)).is_equal(["npcf.move_to", "toy.explore", "npcf.move_to", "toy.rest"])
	assert_str(_move_target(plan.steps[0])).is_equal("toy.yard")
	assert_str(_move_target(plan.steps[2])).is_equal("toy.home_a")


func test_script_plan_needs_a_legal_first_step() -> void:
	var w: NpcfWorld = _world()
	var n: NpcfNpcState = w.npc(&"toy.ana")
	var ref: NpcfPlannerRef = NpcfPlannerRef.new()
	ref.kind = NpcfPlannerRef.Kind.SCRIPT
	n.resolved.planner = ref
	var steps: Array[NpcfScriptStep] = [_step(w, &"toy.chat")]
	# Chat is a daytime action; at 08:00 it is legal, so move the clock to night and it is not.
	w.clock.start_minute = 60
	assert_object(NpcfPlanning.plan_for(w, &"toy.ana", _script_goal(w, steps))).is_null()


func test_later_script_step_is_revalidated_and_the_plan_is_dropped() -> void:
	var w: NpcfWorld = _world()
	w.applier.apply(w, [NpcfStateChange.set_fact(NpcfFramework.GLOBAL, &"toy.discoveries", 1)] as Array[NpcfStateChange], -1, true)
	w.pack.actions[&"toy.spend"] = _spend_action(w)
	w.pack.actions[&"toy.use"] = _use_action(w)
	var n: NpcfNpcState = w.npc(&"toy.ana")
	var ref: NpcfPlannerRef = NpcfPlannerRef.new()
	ref.kind = NpcfPlannerRef.Kind.SCRIPT
	n.resolved.planner = ref
	var steps: Array[NpcfScriptStep] = [_step(w, &"toy.spend"), _step(w, &"toy.use")]
	var plan: NpcfPlan = NpcfPlanning.plan_for(w, &"toy.ana", _script_goal(w, steps))
	assert_array(_kinds(plan)).is_equal(["toy.spend", "toy.use"])
	assert_str(w.executor.start_plan(w, &"toy.ana", plan, _report)).is_equal("ok")

	# Spend ends first and takes the last discovery, so the second step's precondition fails at its start.
	_tick(w, 1)
	assert_bool(n.is_busy()).is_false()
	assert_int(n.plan.size()).is_equal(0)
	assert_int(w.state.get_fact(NpcfFramework.GLOBAL, &"toy.discoveries")).is_equal(0)
	var last: NpcfActionOutcome = n.action_outcomes.back()
	assert_str(String(last.outcome)).is_equal("success")
	w.scheduler.take_due(w, 10)
	assert_str(String(w.scheduler.last_taken(&"toy.ana").reason)).is_equal("plan_step_failed")


func _spend_action(w: NpcfWorld) -> NpcfActionDef:
	var a: NpcfActionDef = NpcfActionDef.new()
	a.id = &"toy.spend"
	a.duration_ticks = 1
	var end: NpcfEffectDef = NpcfEffectDef.new()
	end.kind = NpcfEffectDef.Kind.ADD_FACT
	end.subject_from = NpcfConditionDef.SubjectFrom.GLOBAL
	end.fact = w.pack.fact(&"toy.discoveries")
	end.amount = -1
	a.end_effects = [end] as Array[NpcfEffectDef]
	return a


func _use_action(w: NpcfWorld) -> NpcfActionDef:
	var a: NpcfActionDef = NpcfActionDef.new()
	a.id = &"toy.use"
	a.duration_ticks = 1
	var has_one: NpcfConditionDef = NpcfConditionDef.new()
	has_one.op_kind = NpcfConditionDef.OpKind.FACT
	has_one.subject_from = NpcfConditionDef.SubjectFrom.GLOBAL
	has_one.fact = w.pack.fact(&"toy.discoveries")
	has_one.compare = NpcfConditionDef.Compare.GE
	has_one.value = 1
	a.preconditions = [has_one] as Array[NpcfConditionDef]
	return a


func _location(id: StringName, tag: StringName) -> NpcfLocationDef:
	var l: NpcfLocationDef = NpcfLocationDef.new()
	l.id = id
	l.tags = [tag] as Array[StringName]
	return l


func _edge(a: NpcfLocationDef, b: NpcfLocationDef, ticks: int) -> NpcfEdgeDef:
	var e: NpcfEdgeDef = NpcfEdgeDef.new()
	e.from_location = a
	e.to_location = b
	e.travel_ticks = ticks
	e.bidirectional = true
	return e
