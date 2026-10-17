extends GdUnitTestSuite
## The R15.3 proof: a world saved mid-run and loaded continues exactly like the run that never stopped.

## Seed 11 is the first seed (11..20) whose run has, at tick 557, one NPC walking a path (past its first
## location or mid-edge) while another NPC performs a different action. Found with a probe; the test
## asserts that state holds at the save tick, so a change to the sim that breaks it fails loudly.
const TRAVEL_SEED: int = 11
const TRAVEL_TICK: int = 557
const AFTER_TICKS: int = 500
const DIALOGUE_SEED: int = 1
## The dialogue case saves one tick after the player's line is queued (the conversation input is pending).
const DIALOGUE_TICK: int = 300
const DIALOGUE_AFTER_TICKS: int = 200
const ANA: StringName = &"toy.ana"


## True when one NPC walks a path while another NPC runs a different action.
func _mid_travel_with_action(w: NpcfWorld) -> bool:
	var travelling: bool = false
	var acting: bool = false
	for id: StringName in w.npc_ids:
		var n: NpcfNpcState = w.npc(id)
		if n.running == null or n.running.finished:
			continue
		var r: NpcfRunningAction = n.running
		if r.call.action == &"npcf.move_to":
			travelling = travelling or r.path_index > 0 or r.edge_elapsed > 0
		else:
			acting = acting or r.elapsed > 0
	return travelling and acting


## The event log lines committed after `tick`, in the same format as NpcfEventQueue.log_text.
func _events_after(w: NpcfWorld, tick: int) -> String:
	var lines: PackedStringArray = []
	for e: NpcfEvent in w.events.log:
		if e.tick > tick:
			lines.append(JSON.stringify(e.to_dict(), "", true, true))
	return "\n".join(lines)


## Builds a fresh world from the saved text (same pack and scenario), then restores it.
func _restored(text: String, pack: NpcfLoadedPack) -> NpcfWorld:
	var saved: Dictionary = NpcfSaveCodec.parse(text)
	var b: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), NpcfSaveCodec.seed_of(saved))
	assert_str(NpcfSaveCodec.restore(b, saved)).is_equal("")
	return b


func _has_input(w: NpcfWorld, kind: int) -> bool:
	for i: NpcfInput in w.inputs:
		if i.kind == kind:
			return true
	return false


func test_continuation_matches_unsaved_run() -> void:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var a: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), TRAVEL_SEED)
	for _i: int in TRAVEL_TICK:
		a.step()
	assert_bool(_mid_travel_with_action(a)).is_true()
	var text: String = NpcfSaveCodec.to_text(NpcfSaveCodec.encode(a))
	var b: NpcfWorld = _restored(text, pack)
	for _i: int in AFTER_TICKS:
		a.step()
		b.step()
	var expected: String = _events_after(a, TRAVEL_TICK)
	assert_bool(expected.is_empty()).is_false()
	assert_str(b.events.log_text()).is_equal(expected)
	assert_str(NpcfSaveCodec.to_text(NpcfSaveCodec.encode(a))).is_equal(NpcfSaveCodec.to_text(NpcfSaveCodec.encode(b)))
	a.dispose()
	b.dispose()


func test_continuation_with_dialogue_state() -> void:
	var pack: NpcfLoadedPack = DialogueFixture.load_pack()
	var a: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), DIALOGUE_SEED)
	var placed: Array[NpcfStateChange] = [NpcfStateChange.set_fact(a.sim.player_entity, NpcfFramework.AT, &"toy.home_a")]
	assert_str(a.applier.apply(a, placed, -1, true)).is_equal("")
	for _i: int in DIALOGUE_TICK - 1:
		a.step()
	assert_int(a.dialogue.begin_turn(a, "hello hey", ANA)).is_greater(0)
	assert_bool(_has_input(a, NpcfInput.Kind.CONVERSATION)).is_true()
	var saved_tick: int = a.clock.tick
	var text: String = NpcfSaveCodec.to_text(NpcfSaveCodec.encode(a))
	var b: NpcfWorld = _restored(text, pack)
	for _i: int in DIALOGUE_AFTER_TICKS:
		a.step()
		b.step()
	assert_str(b.events.log_text()).is_equal(_events_after(a, saved_tick))
	assert_str(NpcfSaveCodec.to_text(NpcfSaveCodec.encode(a))).is_equal(NpcfSaveCodec.to_text(NpcfSaveCodec.encode(b)))
	a.dispose()
	b.dispose()
