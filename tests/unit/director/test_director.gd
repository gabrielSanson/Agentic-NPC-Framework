extends GdUnitTestSuite
## The Director: macro variables move with delivered events (one tick later), rules emit targeted directives on
## their cadence and not while active, directives expire before decisions, bias the utility without forcing a
## goal, and hooks may add directives. Scenarios can start macros away from their pack default.

const WORK: StringName = &"toy.work"
const BACK_TO_WORK: StringName = &"toy.back_to_work"
const HOOK_ON_NIL: String = "Invalid call. Nonexistent function 'value' in base 'Nil'."

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## The toy world with Ana, Bo and Cy, at 08:00 unless a start minute is given.
func _world(start_minute: int = 480) -> NpcfWorld:
	var s: NpcfScenarioDef = ToyFixture.basic()
	s.start_minute = start_minute
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), s, 1)
	_worlds.append(w)
	return w


## A copy of the pack's Director, so a test may change it without touching the cached pack.
func _own_director(w: NpcfWorld) -> NpcfDirectorDef:
	w.pack.director = w.pack.director.duplicate() as NpcfDirectorDef
	return w.pack.director


func _chat(w: NpcfWorld) -> void:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = &"toy.chatted"
	e.actors = [&"toy.ana"] as Array[StringName]
	e.location = &"toy.home_a"
	w.emit(e)


func _rule_directives(w: NpcfWorld) -> Array[NpcfDirective]:
	var out: Array[NpcfDirective] = []
	for d: NpcfDirective in w.directives.active():
		if d.origin == BACK_TO_WORK:
			out.append(d)
	return out


func _work_directive(expires: int) -> NpcfDirective:
	var d: NpcfDirective = NpcfDirective.new()
	d.origin = &"test.work"
	d.target_npc = &""
	d.target_tags_none = [&"toy.weary"] as Array[StringName]
	d.goal = WORK
	d.priority = 0.5
	d.expires_tick = expires
	return d


func test_macro_moves_one_tick_after_each_event_and_clamps() -> void:
	var w: NpcfWorld = _world()
	for _i: int in 3:
		_chat(w)
	w.step()
	w.step()
	assert_float(w.director.value(&"toy.idle_pressure")).is_equal_approx(30.0, 0.000001)
	for _i: int in 9:
		_chat(w)
	w.step()
	w.step()
	assert_float(w.director.value(&"toy.idle_pressure")).is_equal_approx(100.0, 0.000001)


func test_rule_fires_on_its_cadence_once_the_pressure_is_reached() -> void:
	var w: NpcfWorld = _world()
	for _i: int in 3:
		_chat(w)
	for _i: int in 29:
		w.step()
	assert_array(_rule_directives(w)).is_empty()
	w.step()
	var found: Array[NpcfDirective] = _rule_directives(w)
	assert_int(found.size()).is_equal(1)
	if found.size() == 1:
		assert_str(String(found[0].goal)).is_equal("toy.work")
		assert_float(found[0].priority).is_equal_approx(0.5, 0.000001)
		assert_int(found[0].expires_tick).is_equal(90)


func test_no_second_directive_while_the_first_is_active() -> void:
	var w: NpcfWorld = _world()
	for _i: int in 3:
		_chat(w)
	for _i: int in 60:
		w.step()
	assert_int(_rule_directives(w).size()).is_equal(1)


func test_expired_directive_is_removed_before_the_rule_emits_again() -> void:
	var w: NpcfWorld = _world()
	for _i: int in 3:
		_chat(w)
	for _i: int in 59:
		w.step()
	var seen: Array[int] = []
	w.phase_probes[&"director"] = func(world: NpcfWorld) -> void:
		var expiries: Array[int] = []
		for d: NpcfDirective in world.directives.active():
			if d.origin == BACK_TO_WORK:
				expiries.append(d.expires_tick)
		seen.assign(expiries)
	w.step()
	# Tick 60 is not an expiry tick; the first directive expires at 90.
	assert_array(seen).is_equal([90])
	for _i: int in 29:
		w.step()
	# Tick 90: the old directive is gone and the rule is due again, so a new one (expiring at 150) replaces it.
	w.step()
	var found: Array[NpcfDirective] = _rule_directives(w)
	assert_int(found.size()).is_equal(1)
	if found.size() == 1:
		assert_int(found[0].expires_tick).is_equal(150)


func test_directive_biases_a_targeted_npc_by_one_plus_k_times_priority() -> void:
	var w: NpcfWorld = _world(600)
	var work: NpcfGoalDef = w.pack.goal(WORK)
	var without: NpcfScoredGoal = w.scorer.score(w, w.view(&"toy.ana"), work)
	var w2: NpcfWorld = _world(600)
	w2.directives.add(_work_directive(90))
	var with_directive: NpcfScoredGoal = w2.scorer.score(w2, w2.view(&"toy.ana"), w2.pack.goal(WORK))
	assert_float(with_directive.bias).is_equal_approx(1.5, 0.000001)
	assert_float(without.bias).is_equal_approx(1.0, 0.000001)
	assert_float(without.score).is_greater(0.0)
	assert_float(with_directive.score / without.score).is_equal_approx(1.5, 0.000001)


func test_directive_never_forces_a_goal_outside_its_schedule() -> void:
	var w: NpcfWorld = _world(480)
	w.directives.add(_work_directive(90))
	var s: NpcfScoredGoal = w.scorer.score(w, w.view(&"toy.ana"), w.pack.goal(WORK))
	assert_float(s.score).is_equal(0.0)


func test_target_query_skips_npcs_with_an_excluded_tag() -> void:
	var w: NpcfWorld = _world(600)
	w.directives.add(_work_directive(90))
	w.applier.apply(w, [NpcfStateChange.tag_change(&"toy.bo", &"toy.weary", true)] as Array[NpcfStateChange], -1, true)
	assert_float(w.scorer.score(w, w.view(&"toy.ana"), w.pack.goal(WORK)).bias).is_equal_approx(1.5, 0.000001)
	assert_float(w.scorer.score(w, w.view(&"toy.bo"), w.pack.goal(WORK)).bias).is_equal_approx(1.0, 0.000001)


func test_hook_directive_is_added_and_a_failing_hook_adds_none() -> void:
	var w: NpcfWorld = _world()
	var director: NpcfDirectorDef = _own_director(w)
	director.hook = load("res://tests/fixtures/hooks/director_rest.gd") as Script
	director.hook_cadence_ticks = 1
	_chat(w)
	w.step()
	w.step()
	var found: Array[NpcfDirective] = []
	for d: NpcfDirective in w.directives.active():
		if d.origin == &"npcf.director_hook":
			found.append(d)
	assert_int(found.size()).is_equal(1)
	if found.size() == 1:
		assert_str(String(found[0].goal)).is_equal("toy.rest")
		assert_float(found[0].priority).is_equal_approx(0.4, 0.000001)
		assert_int(found[0].expires_tick).is_equal(w.clock.tick + 10)

	var broken: NpcfWorld = _world()
	var broken_director: NpcfDirectorDef = _own_director(broken)
	var hook: Script = load("res://tests/fixtures/hooks/error_director.gd") as Script
	broken_director.hook = hook
	broken_director.hook_cadence_ticks = 1
	broken.hooks.log_failures = false
	_chat(broken)
	# The fixture hook fails on every call. Each step calls it once, and each failure is consumed here.
	await assert_error(func() -> void: broken.step()).is_runtime_error(HOOK_ON_NIL)
	await assert_error(func() -> void: broken.step()).is_runtime_error(HOOK_ON_NIL)
	assert_int(broken.hooks.failure_count(hook)).is_equal(2)
	for d: NpcfDirective in broken.directives.active():
		assert_str(String(d.origin)).is_not_equal("npcf.director_hook")


func test_scenario_macro_start_sets_the_value_and_the_rule_fires_without_chat() -> void:
	var s: NpcfScenarioDef = ToyFixture.basic()
	s.macro_start = {&"toy.idle_pressure": 40.0}
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), s, 1)
	_worlds.append(w)
	assert_float(w.director.value(&"toy.idle_pressure")).is_equal_approx(40.0, 0.000001)
	for _i: int in 30:
		w.step()
	assert_int(_rule_directives(w).size()).is_equal(1)
