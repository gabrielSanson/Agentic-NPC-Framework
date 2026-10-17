extends GdUnitTestSuite
## World state and the effect applier: batch validation, each scope, global subject rules, fact change
## events and bounded adds. Uses the real toy pack; one test adds an entity-scoped fact inline.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(extra_entity_fact: bool = false) -> NpcfWorld:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	if extra_entity_fact:
		var mood: NpcfFactDef = NpcfFactDef.new()
		mood.id = &"toy.mood"
		mood.scope = NpcfFactDef.Scope.ENTITY
		mood.value_type = NpcfFactDef.ValueType.BOOL
		mood.default_value = false
		mood.public = false
		pack.facts[mood.id] = mood
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _apply(w: NpcfWorld, changes: Array[NpcfStateChange]) -> String:
	return w.applier.apply(w, changes, -1)


func _kind_count(w: NpcfWorld, kind: StringName) -> int:
	var n: int = 0
	for e: NpcfEvent in w.events.log:
		if e.kind == kind:
			n += 1
	return n


func _last_of(w: NpcfWorld, kind: StringName) -> NpcfEvent:
	var found: NpcfEvent = null
	for e: NpcfEvent in w.events.log:
		if e.kind == kind:
			found = e
	return found


func test_batch_with_one_invalid_change_applies_nothing() -> void:
	var w: NpcfWorld = _world()
	var changes: Array[NpcfStateChange] = [
		NpcfStateChange.set_fact(&"npcf.global", &"toy.discoveries", 5),
		NpcfStateChange.set_fact(&"npcf.global", &"toy.discoveries", -1),
	]
	var err: String = _apply(w, changes)
	assert_str(err).starts_with("changes[1]: value -1 is outside 0")
	assert_int(w.state.get_fact(&"npcf.global", &"toy.discoveries")).is_equal(0)
	assert_int(w.events.log.size()).is_equal(0)


func test_global_scope_reads_and_writes() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.state.get_fact(&"npcf.global", &"toy.discoveries")).is_equal(0)
	var err: String = _apply(w, [NpcfStateChange.set_fact(&"npcf.global", &"toy.discoveries", 7)] as Array[NpcfStateChange])
	assert_str(err).is_equal("")
	assert_int(w.state.get_fact(&"npcf.global", &"toy.discoveries")).is_equal(7)


func test_global_fact_with_another_subject_is_rejected() -> void:
	var w: NpcfWorld = _world()
	var err: String = _apply(w, [NpcfStateChange.set_fact(&"toy.ana", &"toy.discoveries", 1)] as Array[NpcfStateChange])
	assert_str(err).contains("global fact subject must be \"npcf.global\"")
	assert_int(w.state.get_fact(&"toy.ana", &"toy.discoveries")).is_equal(0)


func test_location_scope_reads_and_writes() -> void:
	var w: NpcfWorld = _world()
	assert_bool(w.state.get_fact(&"toy.home_a", &"toy.safe")).is_true()
	assert_bool(w.state.get_fact(&"toy.yard", &"toy.safe")).is_false()
	var err: String = _apply(w, [NpcfStateChange.set_fact(&"toy.yard", &"toy.safe", true)] as Array[NpcfStateChange])
	assert_str(err).is_equal("")
	assert_bool(w.state.get_fact(&"toy.yard", &"toy.safe")).is_true()
	var bad: String = _apply(w, [NpcfStateChange.set_fact(&"toy.ana", &"toy.safe", true)] as Array[NpcfStateChange])
	assert_str(bad).contains("is not a location")


func test_entity_scope_reads_and_writes_and_rejects_non_entities() -> void:
	var w: NpcfWorld = _world(true)
	assert_bool(w.state.get_fact(&"toy.bo", &"toy.mood")).is_false()
	var err: String = _apply(w, [NpcfStateChange.set_fact(&"toy.bo", &"toy.mood", true)] as Array[NpcfStateChange])
	assert_str(err).is_equal("")
	assert_bool(w.state.get_fact(&"toy.bo", &"toy.mood")).is_true()
	var bad: String = _apply(w, [NpcfStateChange.set_fact(&"toy.nobody", &"toy.mood", true)] as Array[NpcfStateChange])
	assert_str(bad).contains("is not an entity")


func test_entity_fact_change_emits_event_at_the_entity_location() -> void:
	var w: NpcfWorld = _world(true)
	_apply(w, [NpcfStateChange.set_fact(&"toy.ana", &"toy.mood", true)] as Array[NpcfStateChange])
	var e: NpcfEvent = _last_of(w, NpcfFramework.FACT_CHANGED)
	assert_object(e).is_not_null()
	if e == null:
		return
	assert_str(String(e.location)).is_equal("toy.home_a")
	assert_int(e.visibility).is_equal(NpcfEvent.Visibility.LOCAL)
	var subject: StringName = e.payload[&"subject"]
	var fact: StringName = e.payload[&"fact"]
	assert_str(String(subject)).is_equal("toy.ana")
	assert_str(String(fact)).is_equal("toy.mood")
	assert_bool(e.payload[&"value"]).is_true()


func test_location_fact_change_emits_event_at_that_location() -> void:
	var w: NpcfWorld = _world()
	_apply(w, [NpcfStateChange.set_fact(&"toy.home_a", &"toy.safe", false)] as Array[NpcfStateChange])
	var e: NpcfEvent = _last_of(w, NpcfFramework.FACT_CHANGED)
	assert_object(e).is_not_null()
	if e != null:
		assert_str(String(e.location)).is_equal("toy.home_a")


func test_global_fact_change_is_public() -> void:
	var w: NpcfWorld = _world()
	_apply(w, [NpcfStateChange.set_fact(&"npcf.global", &"toy.discoveries", 3)] as Array[NpcfStateChange])
	var e: NpcfEvent = _last_of(w, NpcfFramework.FACT_CHANGED)
	assert_object(e).is_not_null()
	if e != null:
		assert_int(e.visibility).is_equal(NpcfEvent.Visibility.PUBLIC)
		assert_str(String(e.location)).is_equal("")


func test_unchanged_value_emits_nothing() -> void:
	var w: NpcfWorld = _world()
	_apply(w, [NpcfStateChange.set_fact(&"toy.home_a", &"toy.safe", true)] as Array[NpcfStateChange])
	assert_int(_kind_count(w, NpcfFramework.FACT_CHANGED)).is_equal(0)


func test_quiet_apply_emits_nothing() -> void:
	var w: NpcfWorld = _world()
	var err: String = w.applier.apply(w, [NpcfStateChange.set_fact(&"npcf.global", &"toy.discoveries", 9)] as Array[NpcfStateChange], -1, true)
	assert_str(err).is_equal("")
	assert_int(w.state.get_fact(&"npcf.global", &"toy.discoveries")).is_equal(9)
	assert_int(w.events.log.size()).is_equal(0)


func test_add_fact_clamps_to_bounds() -> void:
	var w: NpcfWorld = _world()
	_apply(w, [NpcfStateChange.add_fact(&"npcf.global", &"toy.discoveries", 200000)] as Array[NpcfStateChange])
	assert_int(w.state.get_fact(&"npcf.global", &"toy.discoveries")).is_equal(100000)
	_apply(w, [NpcfStateChange.add_fact(&"npcf.global", &"toy.discoveries", -500000)] as Array[NpcfStateChange])
	assert_int(w.state.get_fact(&"npcf.global", &"toy.discoveries")).is_equal(0)


func test_add_fact_on_a_bool_fact_is_rejected() -> void:
	var w: NpcfWorld = _world()
	var err: String = _apply(w, [NpcfStateChange.add_fact(&"toy.home_a", &"toy.safe", 1)] as Array[NpcfStateChange])
	assert_str(err).contains("ADD_FACT needs an int or float fact")


func test_tag_change_is_applied_and_announced() -> void:
	var w: NpcfWorld = _world()
	_apply(w, [NpcfStateChange.tag_change(&"toy.ana", &"toy.tired", true)] as Array[NpcfStateChange])
	assert_bool(w.npc(&"toy.ana").has_tag(&"toy.tired")).is_true()
	var e: NpcfEvent = _last_of(w, NpcfFramework.TAGS_CHANGED)
	assert_object(e).is_not_null()
	if e != null:
		assert_str(String(e.location)).is_equal("toy.home_a")
		assert_bool(e.payload[&"added"]).is_true()
	_apply(w, [NpcfStateChange.tag_change(&"toy.ana", &"toy.tired", false)] as Array[NpcfStateChange])
	assert_bool(w.npc(&"toy.ana").has_tag(&"toy.tired")).is_false()
