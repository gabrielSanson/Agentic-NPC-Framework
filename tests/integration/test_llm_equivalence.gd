extends GdUnitTestSuite
## LLM on and off give the same decisions and the same events (R8.7): the same scripted turns, once with authored
## lines only and once with the line generator answering through the fake transport.

const ANA: StringName = &"toy.ana"
const SEED: int = 13
const TICKS: int = 1440
const TURN_TICKS: Array[int] = [60, 300, 700, 1100]
const VALID: String = '{"line":"Hi there, friend.","cited_facts":[],"action":null}'

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## Runs the scripted turns and returns [decision log text, event log text]. The probe appends to an Array, because a
## lambda captures a packed array by value.
func _run(with_llm: bool) -> Array:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), SEED)
	_worlds.append(w)
	if with_llm:
		var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
		for _i: int in TURN_TICKS.size() * 2:
			transport.replies.append(NpcfLlmReply.make(&"ok", VALID, 5))
		w.dialogue.generator = NpcfLlmLineGenerator.new(transport)
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.player", NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	var decisions: Array[String] = []
	w.phase_probes[&"decisions"] = func(p: NpcfWorld) -> void:
		for id: StringName in p.npc_ids:
			for r: NpcfDecisionRecord in p.npc(id).decision_records:
				if r.tick == p.clock.tick:
					decisions.append(JSON.stringify(r.to_dict(), "", true, true))
	for t: int in range(1, TICKS + 1):
		if TURN_TICKS.has(t):
			w.dialogue.begin_turn(w, "hello hey", ANA)
		w.step()
	return ["\n".join(PackedStringArray(decisions)), w.events.log_text()]


func test_decision_and_event_logs_match_with_llm_on_and_off() -> void:
	var off: Array = _run(false)
	var on: Array = _run(true)
	var off_decisions: String = off[0]
	assert_bool(off_decisions.is_empty()).is_false()
	assert_str(str(on[0])).is_equal(off_decisions)
	assert_str(str(on[1])).is_equal(str(off[1]))
