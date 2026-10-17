extends GdUnitTestSuite
## Witnessed news reaches a non-witness through toy.chat: a teller who saw a sighting at the yard tells a listener
## who arrives there afterwards, and the listener holds the belief as told-by.
##
## The 1,440-tick variant does not apply: nobody is at the yard when the sighting is reported, so nobody can witness
## it and no teller exists. The chat is started and finished directly instead, through the executor.

const YARD: StringName = &"toy.yard"


func test_chat_passes_a_witnessed_sighting_to_a_listener_who_was_not_there() -> void:
	var s: NpcfScenarioDef = ToyFixture.basic()
	s.start_minute = 600  # 10:00, so the daytime hook passes
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), s, 1)
	var ana: StringName = &"toy.ana"
	var bo: StringName = &"toy.bo"
	# Ana is at the yard alone and sees the sighting.
	w.applier.apply(w, [NpcfStateChange.set_fact(ana, NpcfFramework.AT, YARD)] as Array[NpcfStateChange], -1, true)
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = &"toy.spotted"
	e.location = YARD
	w.emit(e)
	w.delivery.deliver_pending(w)
	var witnessed: NpcfBelief = w.npc(ana).beliefs.get_belief(YARD, &"toy.sighting")
	assert_int(witnessed.source if witnessed != null else -1).is_equal(NpcfBelief.Source.WITNESSED)
	# Bo arrives at the yard after the sighting and before the chat.
	w.applier.apply(w, [NpcfStateChange.set_fact(bo, NpcfFramework.AT, YARD)] as Array[NpcfStateChange], -1, true)
	var no_args: Dictionary[StringName, Variant] = {}
	var call: NpcfActionCall = NpcfActionCall.make(ana, &"toy.chat", no_args, w.clock.tick)
	assert_str(String(w.executor.start(w, ana, call))).is_equal("ok")
	w.executor.finish(w, ana, true, &"")
	var heard: NpcfBelief = w.npc(bo).beliefs.get_belief(YARD, &"toy.sighting")
	assert_object(heard).is_not_null()
	if heard != null:
		assert_int(heard.source).is_equal(NpcfBelief.Source.TOLD_BY)
		assert_str(String(heard.teller)).is_equal("toy.ana")
	w.dispose()
