extends GdUnitTestSuite
## One test per merge rule of NpcfResolver (archetype -> personalities -> character -> cast entry).


func _char(m: NpcfPackManifest) -> NpcfCharacterDef:
	return MiniPackFixture.character(m, &"toy.ana")


func test_references_replace_with_the_last_non_null_layer() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var arch_sched: NpcfScheduleDef = NpcfScheduleDef.new()
	var char_sched: NpcfScheduleDef = NpcfScheduleDef.new()
	var cast_sched: NpcfScheduleDef = NpcfScheduleDef.new()
	m.archetypes[0].schedule = arch_sched
	_char(m).schedule = char_sched
	var entry: NpcfCastEntry = MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home"))
	var r: NpcfResolvedCharacter = NpcfResolver.resolve(entry)
	assert_object(r.schedule).is_same(char_sched)
	entry.schedule = cast_sched
	r = NpcfResolver.resolve(entry)
	assert_object(r.schedule).is_same(cast_sched)
	assert_str(String(r.start_location)).is_equal("toy.home")


func test_dictionaries_merge_later_wins() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	_char(m).need_start = {&"toy.energy": 600}
	var entry: NpcfCastEntry = MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home"))
	entry.need_start = {&"toy.energy": 500}
	var r: NpcfResolvedCharacter = NpcfResolver.resolve(entry)
	assert_int(r.need_start[&"toy.energy"]).is_equal(500)
	entry.need_start = {}
	r = NpcfResolver.resolve(entry)
	assert_int(r.need_start[&"toy.energy"]).is_equal(600)


func test_goal_multipliers_multiply_across_layers() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var diligent: NpcfPersonalityDef = NpcfPersonalityDef.new()
	diligent.id = &"toy.diligent"
	diligent.goal_multipliers = {&"toy.rest": 0.8}
	m.personalities.append(diligent)
	_char(m).personalities = [m.personalities[0], diligent]
	var r: NpcfResolvedCharacter = NpcfResolver.resolve(MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home")))
	assert_float(r.goal_multiplier(&"toy.rest")).is_equal_approx(1.2, 0.000001)
	_char(m).goal_multipliers = {&"toy.rest": 0.5}
	r = NpcfResolver.resolve(MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home")))
	assert_float(r.goal_multiplier(&"toy.rest")).is_equal_approx(0.6, 0.000001)
	assert_float(r.goal_multiplier(&"toy.unknown")).is_equal(1.0)


func test_tags_and_goals_append_without_duplicates() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.archetypes[0].tags = [&"toy.a", &"toy.b"]
	m.personalities[0].tags_add = [&"toy.b", &"toy.c"]
	_char(m).tags_add = [&"toy.c", &"toy.d"]
	var explore: NpcfGoalDef = NpcfGoalDef.new()
	explore.id = &"toy.explore"
	var rest: NpcfGoalDef = m.goals[0]
	_char(m).extra_goals = [rest, explore]
	var entry: NpcfCastEntry = MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home"))
	entry.tags_add = [&"toy.d", &"toy.e"]
	var r: NpcfResolvedCharacter = NpcfResolver.resolve(entry)
	assert_array(r.tags).contains_exactly([&"toy.a", &"toy.b", &"toy.c", &"toy.d", &"toy.e"])
	var goal_ids: Array[StringName] = []
	for g: NpcfGoalDef in r.goals:
		goal_ids.append(g.id)
	assert_array(goal_ids).contains_exactly([&"toy.rest", &"toy.explore"])


func test_voice_concatenates_in_layer_order() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.personalities[0].voice = "Tired and blunt."
	_char(m).voice = "  Speaks slowly.  "
	var r: NpcfResolvedCharacter = NpcfResolver.resolve(MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home")))
	assert_str(r.voice).is_equal("Tired and blunt. Speaks slowly.")


func test_speech_instruction_concatenates_in_layer_order() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var p2: NpcfPersonalityDef = NpcfPersonalityDef.new()
	p2.id = &"toy.second"
	p2.speech_instruction = " P2. "
	m.personalities[0].speech_instruction = "P1."
	_char(m).personalities = [m.personalities[0], p2]
	_char(m).speech_instruction = "C."
	_char(m).speech_voice_id = " v1 "
	var r: NpcfResolvedCharacter = NpcfResolver.resolve(MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home")))
	assert_str(r.speech_instruction).is_equal("P1. P2. C.")
	assert_str(r.speech_voice_id).is_equal("v1")


func test_decision_period_is_at_least_one() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	m.archetypes[0].decision_period_ticks = 0
	var r: NpcfResolvedCharacter = NpcfResolver.resolve(MiniPackFixture.cast_entry(_char(m), MiniPackFixture.location(m, &"toy.home")))
	assert_int(r.decision_period_ticks).is_equal(1)
	assert_str(String(r.planner_id())).is_equal("npcf.single_step")
