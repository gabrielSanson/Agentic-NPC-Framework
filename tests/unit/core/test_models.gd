extends GdUnitTestSuite


func test_fact_and_event_dicts() -> void:
	var f: NpcfFact = NpcfFact.make(&"toy.ana", &"npcf.at", &"toy.yard")
	assert_dict(f.to_dict()).is_equal({"subject": "toy.ana", "fact": "npcf.at", "value": "&toy.yard"})
	var e: NpcfEvent = NpcfEvent.new()
	e.id = 3
	e.kind = &"toy.helped"
	e.actors = [&"toy.ana"]
	e.payload = {&"amount": 2, &"who": &"toy.bo"}
	var d: Dictionary = e.to_dict()
	assert_str(str(d["payload"])).is_equal(str({"amount": 2, "who": "&toy.bo"}))
	var actors: Array = d["actors"]
	assert_array(actors).contains_exactly(["toy.ana"])


func test_directive_targets() -> void:
	var d: NpcfDirective = NpcfDirective.new()
	d.target_tags_all = [&"toy.worker"]
	d.target_tags_none = [&"toy.sick"]
	var worker: Array[StringName] = [&"toy.worker"]
	var sick: Array[StringName] = [&"toy.worker", &"toy.sick"]
	assert_bool(d.targets(&"toy.ana", worker)).is_true()
	assert_bool(d.targets(&"toy.ana", sick)).is_false()
	var personal: NpcfDirective = NpcfDirective.new()
	personal.target_npc = &"toy.bo"
	assert_bool(personal.targets(&"toy.bo", [] as Array[StringName])).is_true()
	assert_bool(personal.targets(&"toy.ana", worker)).is_false()


func test_state_change_builders() -> void:
	var c: NpcfStateChange = NpcfStateChange.need_delta(&"toy.ana", &"toy.energy", -5)
	assert_int(c.kind).is_equal(NpcfStateChange.Kind.NEED_DELTA)
	assert_int(c.amount).is_equal(-5)
	assert_str(String(c.need)).is_equal("toy.energy")


func test_invariant_failure_format() -> void:
	var f: NpcfInvariantFailure = NpcfInvariantFailure.make(&"npcf.need_bounds", 12, [&"toy.ana"] as Array[StringName], "toy.energy is 1200")
	assert_str(f.format()).is_equal("invariant npcf.need_bounds failed at tick 12 for [toy.ana]: toy.energy is 1200")


func test_typed_members() -> void:
	var b: NpcfBelief = NpcfBelief.new()
	b.tellers.append(&"toy.bo")
	assert_int(b.tellers.get_typed_builtin()).is_equal(TYPE_STRING_NAME)
	var call: NpcfActionCall = NpcfActionCall.make(&"toy.ana", &"toy.rest", {} as Dictionary[StringName, Variant], 4)
	assert_int(call.args.get_typed_key_builtin()).is_equal(TYPE_STRING_NAME)
	assert_int(call.decision_tick).is_equal(4)
