extends GdUnitTestSuite
## Delivery: recipients by participation, witnessing and broadcast; sorted handling; template and hook
## mappings; framework mappings for arrived, departed and fact_changed. Uses the toy pack. Ana and Cy
## start at home_a, Bo at home_b.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(mutate: Callable = Callable()) -> NpcfWorld:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	if mutate.is_valid():
		mutate.call(pack)
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _emit(w: NpcfWorld, kind: StringName, actors: Array[StringName], location: StringName,
		targets: Array[StringName] = [], payload: Dictionary[StringName, Variant] = {}) -> NpcfEvent:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = kind
	e.actors = actors
	e.targets = targets
	e.location = location
	e.payload = payload
	var id: int = w.emit(e)
	assert(id >= 0, "emit failed: " + w.events.last_error)
	return e


func _belief(w: NpcfWorld, npc: StringName, subject: StringName, fact_id: StringName) -> NpcfBelief:
	return w.npc(npc).beliefs.get_belief(subject, fact_id)


func test_participant_and_witness_receive_and_others_do_not() -> void:
	var w: NpcfWorld = _world()
	var e: NpcfEvent = _emit(w, &"toy.chatted", [&"toy.ana"] as Array[StringName], &"toy.home_a")
	var recips: Dictionary[StringName, int] = w.delivery.recipients(w, e)
	assert_int(recips.size()).is_equal(2)
	assert_int(recips[&"toy.ana"]).is_equal(NpcfBelief.Source.PARTICIPANT)
	assert_int(recips[&"toy.cy"]).is_equal(NpcfBelief.Source.WITNESSED)
	assert_bool(recips.has(&"toy.bo")).is_false()


func test_public_event_is_broadcast_to_everyone_else_with_the_kind_confidence() -> void:
	var w: NpcfWorld = _world()
	w.applier.apply(w, [NpcfStateChange.set_fact(&"npcf.global", &"toy.discoveries", 1)] as Array[NpcfStateChange], -1)
	var e: NpcfEvent = w.events.log.back()
	assert_int(e.visibility).is_equal(NpcfEvent.Visibility.PUBLIC)
	var recips: Dictionary[StringName, int] = w.delivery.recipients(w, e)
	assert_int(recips[&"toy.bo"]).is_equal(NpcfBelief.Source.BROADCAST)
	assert_int(recips[&"toy.ana"]).is_equal(NpcfBelief.Source.BROADCAST)
	w.delivery.deliver_pending(w)
	var b: NpcfBelief = _belief(w, &"toy.bo", &"npcf.global", &"toy.discoveries")
	assert_object(b).is_not_null()
	if b != null:
		assert_int(b.source).is_equal(NpcfBelief.Source.BROADCAST)
		assert_int(b.confidence).is_equal(w.events.kind_def(NpcfFramework.FACT_CHANGED).broadcast_confidence)


func test_participants_only_reaches_only_participants() -> void:
	var w: NpcfWorld = _world()
	var payload: Dictionary[StringName, Variant] = {&"subject": &"toy.home_a", &"fact": &"toy.safe", &"value": false}
	var e: NpcfEvent = _emit(w, NpcfFramework.EXPECTATION_FAILED, [&"toy.ana"] as Array[StringName], &"toy.home_a", [] as Array[StringName], payload)
	var recips: Dictionary[StringName, int] = w.delivery.recipients(w, e)
	assert_array(recips.keys()).is_equal([&"toy.ana"])


func test_recipients_are_in_sorted_id_order() -> void:
	var w: NpcfWorld = _world()
	w.applier.apply(w, [NpcfStateChange.set_fact(&"npcf.global", &"toy.discoveries", 2)] as Array[NpcfStateChange], -1)
	var e: NpcfEvent = w.events.log.back()
	var recips: Dictionary[StringName, int] = w.delivery.recipients(w, e)
	assert_array(recips.keys()).is_equal([&"toy.ana", &"toy.bo", &"toy.cy"])


func test_templates_read_each_subject_and_value_source() -> void:
	var w: NpcfWorld = _world(_templated_chatted)
	_emit(w, &"toy.chatted", [&"toy.ana"] as Array[StringName], &"toy.home_a", [&"toy.bo"] as Array[StringName],
			{&"count": 4, &"who": &"toy.cy"})
	w.delivery.deliver_pending(w)
	var cy: StringName = &"toy.cy"
	assert_bool(_belief(w, cy, &"toy.home_a", &"toy.safe").value).is_true()
	assert_bool(_belief(w, cy, &"toy.ana", &"toy.mood").value).is_true()
	assert_bool(_belief(w, cy, &"toy.bo", &"toy.mood").value).is_false()
	assert_bool(_belief(w, cy, &"toy.cy", &"toy.mood").value).is_true()
	assert_int(_belief(w, cy, &"npcf.global", &"toy.discoveries").value).is_equal(4)


## Replaces the chat event kind with one that has five templates covering every subject and value source.
static func _templated_chatted(pack: NpcfLoadedPack) -> void:
	var mood: NpcfFactDef = NpcfFactDef.new()
	mood.id = &"toy.mood"
	mood.scope = NpcfFactDef.Scope.ENTITY
	mood.value_type = NpcfFactDef.ValueType.BOOL
	mood.default_value = false
	pack.facts[mood.id] = mood
	var kind: NpcfEventKindDef = NpcfEventKindDef.new()
	kind.id = &"toy.chatted"
	kind.salience = 40
	kind.payload_fields = [NpcfFieldDef.make(&"count", NpcfFieldDef.FieldType.INT), NpcfFieldDef.make(&"who", NpcfFieldDef.FieldType.STRING_NAME)]
	kind.beliefs = [
		_template(pack.facts[&"toy.safe"], NpcfFactTemplate.SubjectFrom.LOCATION, NpcfFactTemplate.ValueFrom.LITERAL, true),
		_template(mood, NpcfFactTemplate.SubjectFrom.ACTOR_0, NpcfFactTemplate.ValueFrom.LITERAL, true),
		_template(pack.facts[&"toy.discoveries"], NpcfFactTemplate.SubjectFrom.GLOBAL, NpcfFactTemplate.ValueFrom.PAYLOAD, null, &"count"),
		_template(mood, NpcfFactTemplate.SubjectFrom.TARGET_0, NpcfFactTemplate.ValueFrom.LITERAL, false),
		_template(mood, NpcfFactTemplate.SubjectFrom.PAYLOAD, NpcfFactTemplate.ValueFrom.LITERAL, true, &"", &"who"),
	] as Array[NpcfFactTemplate]
	pack.event_kinds[kind.id] = kind


static func _template(f: NpcfFactDef, subject_from: int, value_from: int, literal: Variant,
		value_field: StringName = &"", subject_field: StringName = &"") -> NpcfFactTemplate:
	var t: NpcfFactTemplate = NpcfFactTemplate.new()
	t.fact = f
	t.subject_from = subject_from
	t.value_from = value_from
	t.value_literal = literal
	t.value_field = value_field
	t.subject_field = subject_field
	return t


func test_mapper_hook_maps_the_event_for_each_receiver() -> void:
	var w: NpcfWorld = _world(_hooked_chatted)
	_emit(w, &"toy.chatted", [&"toy.ana"] as Array[StringName], &"toy.home_a")
	w.delivery.deliver_pending(w)
	var b: NpcfBelief = _belief(w, &"toy.cy", &"toy.cy", &"toy.mood")
	assert_object(b).is_not_null()
	if b != null:
		assert_bool(b.value).is_false()
		assert_int(b.source).is_equal(NpcfBelief.Source.WITNESSED)


static func _hooked_chatted(pack: NpcfLoadedPack) -> void:
	var kind: NpcfEventKindDef = pack.event_kinds[&"toy.chatted"].duplicate() as NpcfEventKindDef
	kind.mapper = load("res://tests/fixtures/hooks/ok_mapper.gd") as Script
	pack.event_kinds[kind.id] = kind


func test_arrived_maps_to_the_actors_location_for_witnesses() -> void:
	var w: NpcfWorld = _world()
	_emit(w, NpcfFramework.ARRIVED, [&"toy.ana"] as Array[StringName], &"toy.home_a")
	w.delivery.deliver_pending(w)
	var b: NpcfBelief = _belief(w, &"toy.cy", &"toy.ana", NpcfFramework.AT)
	assert_object(b).is_not_null()
	if b != null:
		var where: StringName = b.value
		assert_str(String(where)).is_equal("toy.home_a")


func test_departed_maps_to_no_location() -> void:
	var w: NpcfWorld = _world()
	_emit(w, NpcfFramework.DEPARTED, [&"toy.ana"] as Array[StringName], &"toy.home_a")
	w.delivery.deliver_pending(w)
	var b: NpcfBelief = _belief(w, &"toy.cy", &"toy.ana", NpcfFramework.AT)
	assert_object(b).is_not_null()
	if b != null:
		var nowhere: StringName = b.value
		assert_str(String(nowhere)).is_equal("")


func test_fact_changed_maps_to_the_changed_fact_for_witnesses() -> void:
	var w: NpcfWorld = _world()
	w.applier.apply(w, [NpcfStateChange.set_fact(&"toy.home_a", &"toy.safe", false)] as Array[NpcfStateChange], -1)
	w.delivery.deliver_pending(w)
	var b: NpcfBelief = _belief(w, &"toy.cy", &"toy.home_a", &"toy.safe")
	assert_object(b).is_not_null()
	if b != null:
		assert_bool(b.value).is_false()
	assert_object(_belief(w, &"toy.bo", &"toy.home_a", &"toy.safe")).is_null()


func test_quiet_kinds_leave_no_belief() -> void:
	var w: NpcfWorld = _world()
	_emit(w, NpcfFramework.TAGS_CHANGED, [&"toy.ana"] as Array[StringName], &"toy.home_a", [] as Array[StringName],
			{&"tag": &"toy.tired", &"added": true})
	w.delivery.deliver_pending(w)
	assert_int(w.npc(&"toy.cy").beliefs.size()).is_equal(0)
