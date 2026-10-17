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


## The error text must contain `fragment`, and there must be exactly one error.
func _expect_contains(r: NpcfLoadResult, fragment: String) -> void:
	assert_bool(r.ok).is_false()
	assert_int(r.errors.size()).override_failure_message(r.format_errors()).is_equal(1)
	if r.errors.size() == 1:
		assert_str(r.errors[0].format()).override_failure_message(r.format_errors()).contains(fragment)


func _dim(id: StringName, bands: Dictionary[StringName, Vector2i]) -> NpcfRelDimDef:
	var d: NpcfRelDimDef = NpcfRelDimDef.new()
	d.id = id
	d.min_value = -100
	d.max_value = 100
	d.default_value = 0
	d.bands = bands
	return d


func _social_manifest(dims: Array[NpcfRelDimDef]) -> NpcfPackManifest:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.social = NpcfSocialDef.new()
	m.social.dims = dims
	return m


func test_overlapping_bands() -> void:
	var bands: Dictionary[StringName, Vector2i] = {&"a": Vector2i(0, 50), &"b": Vector2i(40, 60)}
	var m: NpcfPackManifest = _social_manifest([_dim(&"toy.trust", bands)] as Array[NpcfRelDimDef])
	_expect_contains(_load(m), "bands \"a\" and \"b\" overlap")


func test_delta_rule_to_witness() -> void:
	var m: NpcfPackManifest = _social_manifest([_dim(&"toy.trust", {})] as Array[NpcfRelDimDef])
	var kind: NpcfEventKindDef = NpcfEventKindDef.new()
	kind.id = &"toy.chatted"
	m.event_kinds.append(kind)
	var rule: NpcfRelDeltaRule = NpcfRelDeltaRule.new()
	rule.event_kind = kind
	rule.dim = m.social.dims[0]
	rule.from_role = NpcfRelDeltaRule.Role.ACTOR_0
	rule.to_role = NpcfRelDeltaRule.Role.WITNESS
	m.social.delta_rules = [rule] as Array[NpcfRelDeltaRule]
	_expect_contains(_load(m), "to_role must be ACTOR_0 or TARGET_0")


func test_rel_delta_effect_with_unknown_dimension() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var e: NpcfEffectDef = NpcfEffectDef.new()
	e.kind = NpcfEffectDef.Kind.REL_DELTA
	e.dim = &"toy.nope"
	e.amount = 1
	m.actions[0].end_effects = [e] as Array[NpcfEffectDef]
	_expect_contains(_load(m), "unknown relationship dimension \"toy.nope\"")


func test_archetype_rel_default_with_unknown_dimension() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.archetypes[0].rel_defaults = {&"toy.nope": 5}
	_expect_contains(_load(m), "unknown relationship dimension \"toy.nope\"")


func test_scenario_relationship_value_outside_bounds() -> void:
	var m: NpcfPackManifest = _social_manifest([_dim(&"toy.trust", {})] as Array[NpcfRelDimDef])
	var r: NpcfLoadResult = _load(m)
	assert_bool(r.ok).override_failure_message(r.format_errors()).is_true()
	if not r.ok:
		return
	var yard: NpcfLocationDef = MiniPackFixture.location(m, &"toy.yard")
	var bo: NpcfCastEntry = MiniPackFixture.cast_entry(MiniPackFixture.character(m, &"toy.bo"), yard)
	var s: NpcfScenarioDef = MiniPackFixture.scenario(m, [bo] as Array[NpcfCastEntry])
	var seed_rel: NpcfRelSeed = NpcfRelSeed.new()
	seed_rel.from_character = MiniPackFixture.character(m, &"toy.ana")
	seed_rel.to_character = MiniPackFixture.character(m, &"toy.bo")
	seed_rel.values = {&"toy.trust": 150}
	s.relationships = [seed_rel] as Array[NpcfRelSeed]
	var errors: Array[NpcfConfigError] = NpcfPackLoader.new().check_scenario(r.pack, s)
	assert_int(errors.size()).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0].format()).contains("150 is outside -100..100")


func _macro_pack() -> NpcfPackManifest:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.director = NpcfDirectorDef.new()
	var pressure: NpcfMacroVarDef = NpcfMacroVarDef.new()
	pressure.id = &"toy.pressure"
	pressure.min_value = 0.0
	pressure.max_value = 100.0
	pressure.start = 0.0
	m.director.macros = [pressure] as Array[NpcfMacroVarDef]
	return m


func _rule(m: NpcfPackManifest, target: NpcfTagQuery) -> NpcfDirectorRuleDef:
	var r: NpcfDirectorRuleDef = NpcfDirectorRuleDef.new()
	r.id = &"toy.back_to_work"
	r.goal = m.goals[0]
	r.target = target
	m.director.rules = [r] as Array[NpcfDirectorRuleDef]
	return r


func test_director_rule_without_target() -> void:
	var m: NpcfPackManifest = _macro_pack()
	_rule(m, null)
	_expect_contains(_load(m), "needs a target tag query")


func test_director_condition_with_exists() -> void:
	var m: NpcfPackManifest = _macro_pack()
	var r: NpcfDirectorRuleDef = _rule(m, NpcfTagQuery.new())
	var c: NpcfMacroCondition = NpcfMacroCondition.new()
	c.macro = m.director.macros[0]
	c.compare = NpcfConditionDef.Compare.EXISTS
	r.conditions = [c] as Array[NpcfMacroCondition]
	_expect_contains(_load(m), "EXISTS does not apply to a macro")


func test_macro_start_outside_bounds() -> void:
	var m: NpcfPackManifest = _macro_pack()
	m.director.macros[0].start = 150.0
	_expect_contains(_load(m), "150.0 is outside 0.0..100.0")


func test_scenario_macro_start_with_unknown_macro() -> void:
	var m: NpcfPackManifest = _macro_pack()
	var r: NpcfLoadResult = _load(m)
	assert_bool(r.ok).override_failure_message(r.format_errors()).is_true()
	if not r.ok:
		return
	var s: NpcfScenarioDef = MiniPackFixture.scenario(m)
	s.macro_start = {&"toy.nope": 5.0}
	var errors: Array[NpcfConfigError] = NpcfPackLoader.new().check_scenario(r.pack, s)
	assert_int(errors.size()).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0].format()).contains("unknown macro \"toy.nope\"")


## The toy pack with its dialogue copied, so a test can change dialogue fields without touching the cache.
func _toy_with_dialogue() -> NpcfPackManifest:
	var m: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	m.dialogue = m.dialogue.duplicate()
	return m


func _toy_errors(m: NpcfPackManifest) -> Array[NpcfConfigError]:
	return NpcfPackLoader.new().load_pack(m).errors


func test_delivery_question_must_be_a_presentation_question() -> void:
	var m: NpcfPackManifest = _toy_with_dialogue()
	m.dialogue.delivery_question = &"toy.nope"
	var errors: Array[NpcfConfigError] = _toy_errors(m)
	assert_int(errors.size()).is_equal(1)
	if errors.size() == 1:
		assert_bool(errors[0].property_path.ends_with("delivery_question")).is_true()


func test_delivery_instruction_key_must_be_an_option() -> void:
	var m: NpcfPackManifest = _toy_with_dialogue()
	var bad: Dictionary[StringName, String] = {&"toy.furious": "Loud."}
	m.dialogue.delivery_instructions = bad
	var errors: Array[NpcfConfigError] = _toy_errors(m)
	assert_int(errors.size()).is_equal(1)
	if errors.size() == 1:
		assert_bool(errors[0].property_path.ends_with("delivery_instructions")).is_true()


func test_delivery_instructions_without_question_is_an_error() -> void:
	var m: NpcfPackManifest = _toy_with_dialogue()
	m.dialogue.delivery_question = &""
	var errors: Array[NpcfConfigError] = _toy_errors(m)
	assert_int(errors.size()).is_equal(1)
	if errors.size() == 1:
		assert_bool(errors[0].property_path.ends_with("delivery_instructions")).is_true()


func test_toy_pack_with_speech_fields_loads_clean() -> void:
	var errors: Array[NpcfConfigError] = _toy_errors(_toy_with_dialogue())
	assert_int(errors.size()).is_equal(0)
