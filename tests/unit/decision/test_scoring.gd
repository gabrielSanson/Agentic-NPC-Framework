extends GdUnitTestSuite
## Utility scoring: the worked example (U(rest) 0.6494, U(explore) 0.5249 and the switch to rest),
## response curves, compensation, zero compensation under a directive, multiplier clamping and the
## directive bias. Goals are inline; the NPC is Ana from the toy basic scenario (at home_a).

var _worlds: Array[NpcfWorld] = []
var _rest: NpcfGoalDef = null
var _explore: NpcfGoalDef = null


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## A world with the toy pack, plus a public bool fact `toy.mood` that the worked example reads.
func _world() -> NpcfWorld:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var mood: NpcfFactDef = NpcfFactDef.new()
	mood.id = &"toy.mood"
	mood.scope = NpcfFactDef.Scope.ENTITY
	mood.value_type = NpcfFactDef.ValueType.BOOL
	mood.default_value = false
	mood.public = true
	pack.facts[mood.id] = mood
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _need(w: NpcfWorld, id: StringName) -> NpcfNeedDef:
	return w.pack.need(id)


func _need_input(need: NpcfNeedDef, curve: NpcfConsiderationDef.CurveKind) -> NpcfConsiderationDef:
	var c: NpcfConsiderationDef = NpcfConsiderationDef.new()
	c.input = NpcfConsiderationDef.InputKind.NEED
	c.need = need
	c.curve = curve
	return c


func _goal(id: StringName, weight: float, considerations: Array[NpcfConsiderationDef], actions: Array[NpcfActionDef]) -> NpcfGoalDef:
	var g: NpcfGoalDef = NpcfGoalDef.new()
	g.id = id
	g.weight = weight
	g.considerations = considerations
	g.candidate_actions = actions
	return g


## Builds the worked example on Ana: energy 300, curiosity 600, rest multiplier 1.5 * 0.8, a directive
## of priority 0.8 on explore, K = 1. Sets `_rest` and `_explore`.
func _worked_example() -> NpcfWorld:
	var w: NpcfWorld = _world()
	var ana: NpcfNpcState = w.npc(&"toy.ana")
	ana.needs[&"toy.energy"] = 300
	ana.needs[&"toy.curiosity"] = 600
	w.state.write(&"toy.ana", &"toy.mood", true)
	ana.resolved.goal_multipliers[&"x.rest"] = 1.5 * 0.8

	var energy: NpcfNeedDef = _need(w, &"toy.energy")
	var curiosity: NpcfNeedDef = _need(w, &"toy.curiosity")
	var energy_inverted: NpcfConsiderationDef = _need_input(energy, NpcfConsiderationDef.CurveKind.POWER)
	energy_inverted.invert = true
	energy_inverted.exponent = 2.0
	var mood: NpcfConsiderationDef = NpcfConsiderationDef.new()
	mood.input = NpcfConsiderationDef.InputKind.FACT
	mood.fact = w.pack.fact(&"toy.mood")
	mood.curve = NpcfConsiderationDef.CurveKind.LINEAR
	mood.m = 0.8
	mood.b = 0.0
	var rest_actions: Array[NpcfActionDef] = [w.pack.action(&"toy.rest")]
	_rest = _goal(&"x.rest", 1.0, [energy_inverted, mood] as Array[NpcfConsiderationDef], rest_actions)

	var curiosity_linear: NpcfConsiderationDef = _need_input(curiosity, NpcfConsiderationDef.CurveKind.LINEAR)
	var energy_linear: NpcfConsiderationDef = _need_input(energy, NpcfConsiderationDef.CurveKind.LINEAR)
	var explore_actions: Array[NpcfActionDef] = [w.pack.action(&"toy.explore")]
	_explore = _goal(&"x.explore", 1.0, [curiosity_linear, energy_linear] as Array[NpcfConsiderationDef], explore_actions)

	var directive: NpcfDirective = NpcfDirective.new()
	directive.target_npc = &"toy.ana"
	directive.goal = &"x.explore"
	directive.priority = 0.8
	directive.expires_tick = 1000
	w.directives.add(directive)
	ana.resolved.goals.clear()
	ana.resolved.goals.append(_rest)
	ana.resolved.goals.append(_explore)
	return w


func test_worked_example_utilities() -> void:
	var w: NpcfWorld = _worked_example()
	var view: NpcfNpcView = w.view(&"toy.ana")
	var rest: NpcfScoredGoal = w.scorer.score(w, view, _rest)
	var explore: NpcfScoredGoal = w.scorer.score(w, view, _explore)
	assert_float(rest.score).is_equal_approx(0.6494, 0.0001)
	assert_float(explore.score).is_equal_approx(0.5249, 0.0001)
	# The intermediate values behind the numbers: energy 0.3 inverted and squared, mood 0.8.
	assert_float(rest.inputs[0]).is_equal_approx(0.3, 0.000001)
	assert_float(rest.values[0]).is_equal_approx(0.49, 0.000001)
	assert_float(rest.values[1]).is_equal_approx(0.8, 0.000001)
	assert_float(rest.compensated).is_equal_approx(0.541156, 0.000001)
	assert_float(rest.multiplier).is_equal_approx(1.2, 0.000001)
	assert_float(rest.bias).is_equal_approx(1.0, 0.000001)
	assert_float(explore.bias).is_equal_approx(1.8, 0.000001)


func test_worked_example_switches_from_explore_to_rest() -> void:
	var w: NpcfWorld = _worked_example()
	w.npc(&"toy.ana").current_goal = &"x.explore"
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.ana")
	assert_str(String(record.previous_goal)).is_equal("x.explore")
	assert_str(String(record.chosen_goal)).is_equal("x.rest")
	assert_bool(record.kept).is_false()
	assert_bool(record.hysteresis_blocked).is_false()
	assert_str(String(w.npc(&"toy.ana").current_goal)).is_equal("x.rest")
	assert_array(record.scores.map(func(s: NpcfScoredGoal) -> StringName: return s.goal)).is_equal([&"x.rest", &"x.explore"])


func test_curve_shapes() -> void:
	var c: NpcfConsiderationDef = NpcfConsiderationDef.new()
	c.curve = NpcfConsiderationDef.CurveKind.LINEAR
	c.m = 0.5
	c.b = 0.1
	assert_float(NpcfCurves.apply(c, 0.4)).is_equal_approx(0.3, 0.000001)
	assert_float(NpcfCurves.apply(c, 2.0)).is_equal_approx(0.6, 0.000001)
	c.m = 2.0
	c.b = 0.0
	assert_float(NpcfCurves.apply(c, 1.0)).is_equal_approx(1.0, 0.000001)
	assert_float(NpcfCurves.apply(c, -1.0)).is_equal_approx(0.0, 0.000001)

	c.curve = NpcfConsiderationDef.CurveKind.POWER
	c.exponent = 3.0
	assert_float(NpcfCurves.apply(c, 0.5)).is_equal_approx(0.125, 0.000001)

	c.curve = NpcfConsiderationDef.CurveKind.LOGISTIC
	c.k = 10.0
	c.mid = 0.5
	assert_float(NpcfCurves.apply(c, 0.5)).is_equal_approx(0.5, 0.000001)
	assert_float(NpcfCurves.apply(c, 1.0)).is_equal_approx(0.9933071, 0.000001)

	c.curve = NpcfConsiderationDef.CurveKind.STEP
	c.threshold = 0.5
	assert_float(NpcfCurves.apply(c, 0.49)).is_equal_approx(0.0, 0.000001)
	assert_float(NpcfCurves.apply(c, 0.5)).is_equal_approx(1.0, 0.000001)

	c.curve = NpcfConsiderationDef.CurveKind.LINEAR
	c.m = 1.0
	c.b = 0.0
	c.invert = true
	assert_float(NpcfCurves.apply(c, 0.2)).is_equal_approx(0.8, 0.000001)


func test_compensation_of_equal_values() -> void:
	var one: Array[float] = [0.5]
	var two: Array[float] = [0.5, 0.5]
	var three: Array[float] = [0.5, 0.5, 0.5]
	var none: Array[float] = []
	assert_float(NpcfUtilityScorer.compensate(one)).is_equal_approx(0.5, 0.001)
	assert_float(NpcfUtilityScorer.compensate(two)).is_equal_approx(0.390625, 0.001)
	assert_float(NpcfUtilityScorer.compensate(three)).is_equal_approx(0.2963, 0.001)
	assert_float(NpcfUtilityScorer.compensate(none)).is_equal_approx(1.0, 0.000001)


func test_zero_compensated_goal_stays_zero_under_a_directive() -> void:
	var w: NpcfWorld = _world()
	var mood: NpcfConsiderationDef = NpcfConsiderationDef.new()
	mood.input = NpcfConsiderationDef.InputKind.FACT
	mood.fact = w.pack.fact(&"toy.mood")
	mood.curve = NpcfConsiderationDef.CurveKind.LINEAR
	# mood is false for Ana, so this input is 0 and the compensated product is 0.
	var goal: NpcfGoalDef = _goal(&"x.none", 1.0, [mood] as Array[NpcfConsiderationDef], [] as Array[NpcfActionDef])
	var directive: NpcfDirective = NpcfDirective.new()
	directive.target_npc = &"toy.ana"
	directive.goal = &"x.none"
	directive.priority = 1.0
	directive.expires_tick = 1000
	w.directives.add(directive)
	var scored: NpcfScoredGoal = w.scorer.score(w, w.view(&"toy.ana"), goal)
	assert_float(scored.compensated).is_equal_approx(0.0, 0.000001)
	assert_float(scored.bias).is_equal_approx(2.0, 0.000001)
	assert_float(scored.score).is_equal_approx(0.0, 0.000001)


func test_multiplier_is_clamped_at_three() -> void:
	var w: NpcfWorld = _worked_example()
	w.npc(&"toy.ana").resolved.goal_multipliers[&"x.rest"] = 5.0
	var rest: NpcfScoredGoal = w.scorer.score(w, w.view(&"toy.ana"), _rest)
	assert_float(rest.multiplier).is_equal_approx(3.0, 0.000001)
	assert_float(rest.score).is_equal_approx(rest.compensated * 3.0, 0.000001)


func test_directive_bias_is_one_plus_gain_times_priority() -> void:
	var w: NpcfWorld = _worked_example()
	w.sim.directive_gain = 2.0
	var explore: NpcfScoredGoal = w.scorer.score(w, w.view(&"toy.ana"), _explore)
	assert_float(explore.bias).is_equal_approx(1.0 + 2.0 * 0.8, 0.000001)


func test_directives_for_other_npcs_do_not_bias_the_goal() -> void:
	var w: NpcfWorld = _worked_example()
	w.directives.active()[0].target_npc = &"toy.bo"
	var explore: NpcfScoredGoal = w.scorer.score(w, w.view(&"toy.ana"), _explore)
	assert_float(explore.bias).is_equal_approx(1.0, 0.000001)


func test_action_score_is_compensated_value_times_multiplier_over_cost() -> void:
	var w: NpcfWorld = _world()
	var action: NpcfActionDef = w.pack.action(&"toy.rest")
	action.cost = 2.0
	assert_float(w.scorer.score_action(w, w.view(&"toy.ana"), action)).is_equal_approx(0.5, 0.000001)
	action.cost = 0.0
	assert_float(w.scorer.score_action(w, w.view(&"toy.ana"), action)).is_equal_approx(0.0, 0.000001)
