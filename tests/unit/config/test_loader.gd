extends GdUnitTestSuite
## Pack loader: every error class is reported with its exact format() text. Each test starts from
## MiniPackFixture (valid) and breaks it in one place, so the expected output has one error.

const U: String = "<unsaved resource>: "
const HOOKS: String = "res://tests/fixtures/hooks"


func _load(m: NpcfPackManifest, version: String = NpcfVersion.FRAMEWORK, dir: String = HOOKS) -> NpcfLoadResult:
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	return loader.load_pack(m, version, dir)


func _expect_single(r: NpcfLoadResult, expected: String) -> void:
	assert_bool(r.ok).is_false()
	assert_int(r.errors.size()).override_failure_message(r.format_errors()).is_equal(1)
	if r.errors.size() == 1:
		assert_str(r.errors[0].format()).is_equal(expected)


func _condition_hook(m: NpcfPackManifest, script_path: String) -> void:
	var c: NpcfConditionDef = NpcfConditionDef.new()
	c.op_kind = NpcfConditionDef.OpKind.HOOK
	c.hook = load(script_path) as Script
	m.actions[0].preconditions = [c]


func test_valid_fixture_loads_with_framework_definitions() -> void:
	var r: NpcfLoadResult = _load(MiniPackFixture.manifest())
	assert_bool(r.ok).override_failure_message(r.format_errors()).is_true()
	assert_object(r.pack).is_not_null()
	assert_bool(r.pack.facts.has(NpcfFramework.AT)).is_true()
	assert_bool(r.pack.event_kinds.has(NpcfFramework.NEED_THRESHOLD)).is_true()
	assert_bool(r.pack.actions.has(NpcfFramework.MOVE_TO)).is_true()
	assert_int(r.pack.location_index.travel_ticks(&"toy.home", &"toy.yard")).is_equal(5)


func test_bad_namespace() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.pack_namespace = &"Bad"
	_expect_single(_load(m), U + "pack_namespace: \"Bad\" is not a valid namespace "
			+ "(hint: use lowercase letters, digits and _, starting with a letter)")


func test_framework_version_out_of_range() -> void:
	_expect_single(_load(MiniPackFixture.manifest(), "0.4.0"), U + "framework_min: pack supports framework 0.2.0 "
			+ "up to (not including) 0.3.0, running 0.4.0 (hint: update the pack or the framework)")


func test_bad_pack_version() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.pack_version = "1.0"
	_expect_single(_load(m), U + "pack_version: \"1.0\" is not major.minor.patch (hint: for example 1.0.0)")


func test_invalid_id() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.facts[0].id = &"toy"
	_expect_single(_load(m), U + "facts[0].id: \"toy\" does not match %s (hint: IDs look like toy.name)" % NpcfIds.PATTERN)


func test_duplicate_id() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.needs.append(MiniPackFixture.make_need(&"toy.energy", 500, 0))
	_expect_single(_load(m), U + "needs[1].id: duplicate need ID \"toy.energy\" "
			+ "(already defined in <unsaved resource>) (hint: give each need a unique ID)")


func test_unknown_reference() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var explore: NpcfGoalDef = NpcfGoalDef.new()
	explore.id = &"toy.explore"
	m.archetypes[0].goals = [m.goals[0], explore]
	_expect_single(_load(m), U + "archetypes[0].goals[1]: unknown goal \"toy.explore\" "
			+ "(hint: add it to the pack manifest or fix the ID)")


func test_wrong_kind_reference() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var eat_action: NpcfActionDef = NpcfActionDef.new()
	eat_action.id = &"toy.eat"
	m.actions.append(eat_action)
	var eat_goal: NpcfGoalDef = NpcfGoalDef.new()
	eat_goal.id = &"toy.eat"
	m.archetypes[0].goals = [m.goals[0], eat_goal]
	_expect_single(_load(m), U + "archetypes[0].goals[1]: \"toy.eat\" is a action, expected a goal "
			+ "(hint: reference a goal here)")


func test_multiplier_out_of_range() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.personalities[0].goal_multipliers = {&"toy.rest": 4.0}
	_expect_single(_load(m), U + "personalities[0].goal_multipliers[\"toy.rest\"]: 4.0 is outside 0.0..3.0 "
			+ "(hint: lower the multiplier or split it across two personalities)")


func test_need_start_outside_bounds() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.needs[0].start = 2000
	_expect_single(_load(m), U + "needs[0].start: 2000 is outside 0..1000")


func test_fact_default_type_mismatch() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.facts[0].default_value = 5
	_expect_single(_load(m), U + "facts[0].default_value: 5 (int) does not match value type bool "
			+ "(hint: set a bool default)")


func test_condition_cycle() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var all: NpcfConditionDef = NpcfConditionDef.new()
	all.op_kind = NpcfConditionDef.OpKind.ALL
	all.children = [all]
	m.actions[0].preconditions = [all]
	_expect_single(_load(m), U + "actions[0].preconditions[0].children[0]: condition refers back to itself (cycle) "
			+ "(hint: break the cycle)")


func test_dialogue_tier_action_writing_state() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var set_mood: NpcfEffectDef = NpcfEffectDef.new()
	set_mood.kind = NpcfEffectDef.Kind.SET_FACT
	set_mood.fact = m.facts[0]
	set_mood.value = true
	m.actions[0].tier = NpcfActionDef.Tier.DIALOGUE
	m.actions[0].per_tick_need_deltas = {}
	m.actions[0].end_effects = [set_mood]
	_expect_single(_load(m), U + "actions[0].end_effects[0].kind: dialogue-tier actions are presentation only "
			+ "and may not write state (hint: move the effect to a rules-tier action, or use EMIT_EVENT)")


func test_duplicate_cast_entry() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var r: NpcfLoadResult = _load(m)
	var s: NpcfScenarioDef = MiniPackFixture.scenario(m, [MiniPackFixture.cast_entry(
			MiniPackFixture.character(m, &"toy.ana"), MiniPackFixture.location(m, &"toy.yard"))])
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	var errors: Array[NpcfConfigError] = loader.check_scenario(r.pack, s)
	assert_int(errors.size()).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0].format()).is_equal(U + "cast[1].character: NPC \"toy.ana\" is already in the cast "
				+ "(cast[0]) (hint: each NPC may appear once)")


func test_unreachable_location() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.location_graph.locations.append(MiniPackFixture.make_location(&"toy.island", [] as Array[StringName]))
	var r: NpcfLoadResult = _load(m)
	assert_bool(r.ok).is_true()
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	var errors: Array[NpcfConfigError] = loader.check_scenario(r.pack, MiniPackFixture.scenario(m))
	assert_int(errors.size()).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0].format()).is_equal(U + "id: location \"toy.island\" is unreachable from the "
				+ "scenario's start locations (hint: add an edge to it or remove it)")


func test_hook_outside_pack_folder() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	_condition_hook(m, HOOKS + "/ok_condition.gd")
	_expect_single(_load(m, NpcfVersion.FRAMEWORK, "res://tests/fixtures/elsewhere"),
			U + "actions[0].preconditions[0].hook: hook script " + HOOKS + "/ok_condition.gd is outside the pack folder "
			+ "res://tests/fixtures/elsewhere (hint: move the script into the pack)")


func test_hook_with_wrong_base_class() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	_condition_hook(m, HOOKS + "/wrong_base_effect.gd")
	_expect_single(_load(m), U + "actions[0].preconditions[0].hook: hook script %s/wrong_base_effect.gd "
			% HOOKS + "does not extend NpcfConditionHook (hint: change its `extends` line to NpcfConditionHook)")


func test_hook_needing_constructor_arguments() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	_condition_hook(m, HOOKS + "/needs_args_condition.gd")
	_expect_single(_load(m), U + "actions[0].preconditions[0].hook: hook script %s/needs_args_condition.gd "
			% HOOKS + "needs constructor arguments (hint: hooks must be instantiable with no arguments)")


func test_collects_every_error() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.facts[0].default_value = 5
	m.needs[0].start = 2000
	var r: NpcfLoadResult = _load(m)
	assert_bool(r.ok).is_false()
	assert_int(r.errors.size()).is_equal(2)
	if r.errors.size() == 2:
		assert_str(r.errors[0].format()).is_equal(U + "facts[0].default_value: 5 (int) does not match value type bool "
				+ "(hint: set a bool default)")
		assert_str(r.errors[1].format()).is_equal(U + "needs[0].start: 2000 is outside 0..1000")
