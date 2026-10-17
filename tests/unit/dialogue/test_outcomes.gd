extends GdUnitTestSuite
## Rule outcomes: the outcome is decided before the line, the conversation commits at the next tick, deltas apply,
## reveals are kept only when the NPC holds them, hooks fall back to declared outcomes, and player text never
## reaches state.

const ANA: StringName = &"toy.ana"
const PLAYER: StringName = &"toy.player"
const TRUST: StringName = &"toy.trust"
const LIKING: StringName = &"toy.liking"

var _worlds: Array[NpcfWorld] = []
var _lines: Array[Array] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## Records each presentation choice, and how many lines had been emitted when it was made.
class RecordingChooser extends NpcfPresentationChooser:
	var outcomes: Array[StringName] = []
	var lines_emitted_at_choice: Array[int] = []
	var line_counter: Array = []

	func choose(questions: Array[NpcfPresentationQuestionDef], ctx: NpcfDialogueContext, on_done: Callable) -> void:
		outcomes.append(ctx.outcome.result)
		lines_emitted_at_choice.append(line_counter.size())
		super.choose(questions, ctx, on_done)


func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	_lines.clear()
	w.dialogue.line.connect(func(npc: StringName, text: String, line_id: int, source: StringName, _pres: Dictionary) -> void:
		_lines.append([npc, text, line_id, source]))
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(PLAYER, NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w


func _conversations(w: NpcfWorld) -> Array[NpcfEvent]:
	var out: Array[NpcfEvent] = []
	for e: NpcfEvent in w.events.log:
		if e.kind == NpcfFramework.CONVERSATION:
			out.append(e)
	return out


func _sighting_belief(w: NpcfWorld, subject: StringName, value: bool, confidence: int) -> void:
	var meta: NpcfBeliefMeta = NpcfBeliefMeta.new()
	meta.confidence = confidence
	meta.tick = w.clock.tick
	meta.source = NpcfBelief.Source.WITNESSED
	w.npc(ANA).beliefs.put(NpcfFact.make(subject, &"toy.sighting", value), meta)


func test_the_outcome_is_decided_before_the_line_is_chosen() -> void:
	var w: NpcfWorld = _world()
	var chooser: RecordingChooser = RecordingChooser.new()
	chooser.line_counter = _lines
	w.dialogue.chooser = chooser
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_array(chooser.outcomes).contains_exactly([&"toy.friendly"])
	assert_array(chooser.lines_emitted_at_choice).contains_exactly([0])
	assert_int(_lines.size()).is_equal(1)


func test_the_conversation_commits_at_the_next_tick() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_array(_conversations(w)).is_empty()
	assert_int(w.relationships.value(w, ANA, PLAYER, LIKING)).is_equal(0)
	w.step()
	var convs: Array[NpcfEvent] = _conversations(w)
	assert_int(convs.size()).is_equal(1)
	var e: NpcfEvent = convs[0]
	assert_array(e.actors).contains_exactly([PLAYER])
	assert_array(e.targets).contains_exactly([ANA])
	assert_str(str(e.location)).is_equal("toy.home_a")
	assert_str(str(e.payload[&"intent"])).is_equal("toy.greet")
	assert_str(str(e.payload[&"result"])).is_equal("toy.friendly")
	assert_bool(e.payload.has(&"facts")).is_false()
	assert_int(w.relationships.value(w, ANA, PLAYER, LIKING)).is_equal(1)
	assert_int(w.relationships.last_cause(ANA, PLAYER, LIKING)).is_equal(e.id)


func test_an_insult_changes_trust_and_liking() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "you stupid idiot", ANA)).is_equal(1)
	w.step()
	assert_int(w.relationships.value(w, ANA, PLAYER, TRUST)).is_equal(-10)
	assert_int(w.relationships.value(w, ANA, PLAYER, LIKING)).is_equal(-5)


func test_a_held_reveal_is_kept_and_recorded_in_the_event() -> void:
	var w: NpcfWorld = _world()
	_sighting_belief(w, &"toy.yard", true, 80)
	assert_int(w.dialogue.begin_turn(w, "seen any news?", ANA)).is_equal(1)
	var rec: NpcfDialogueTurnRecord = w.dialogue.records[0]
	assert_str(str(rec.result)).is_equal("toy.has_news")
	assert_array(rec.revealed).contains_exactly(["toy.yard/toy.sighting"])
	w.step()
	var e: NpcfEvent = _conversations(w)[0]
	assert_array(e.payload[&"facts"]).contains_exactly(["toy.yard/toy.sighting"])


func test_no_held_sighting_means_no_news_and_no_reveal() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "seen any news?", ANA)).is_equal(1)
	var rec: NpcfDialogueTurnRecord = w.dialogue.records[0]
	assert_str(str(rec.result)).is_equal("toy.no_news")
	assert_array(rec.revealed).is_empty()


func test_a_reveal_the_npc_does_not_hold_is_dropped() -> void:
	var w: NpcfWorld = _world()
	var pack: NpcfLoadedPack = w.pack
	pack.intents[&"toy.ask_news"].hook = load("res://tests/fixtures/hooks/reveal_unheld_intent.gd") as Script
	assert_int(w.dialogue.begin_turn(w, "seen any news?", ANA)).is_equal(1)
	var rec: NpcfDialogueTurnRecord = w.dialogue.records[0]
	assert_array(rec.dropped_reveals).contains_exactly(["toy.home_b/toy.sighting"])
	assert_array(rec.revealed).is_empty()
	w.step()
	assert_bool(_conversations(w)[0].payload.has(&"facts")).is_false()


func test_a_failing_hook_falls_back_to_the_declared_outcome() -> void:
	var w: NpcfWorld = _world()
	w.hooks.log_failures = false
	var hook: Script = load("res://tests/fixtures/hooks/error_intent.gd") as Script
	w.pack.intents[&"toy.greet"].hook = hook
	var holder: Array = [-1]
	await assert_error(func() -> void: holder[0] = w.dialogue.begin_turn(w, "hello hey", ANA)) \
			.is_runtime_error("Invalid call. Nonexistent function 'npc_id' in base 'Nil'.")
	assert_int(holder[0]).is_equal(1)
	assert_int(w.hooks.failure_count(hook)).is_equal(1)
	assert_str(str(w.dialogue.records[0].result)).is_equal("toy.friendly")
	assert_str(str(_lines[0][1])).is_not_empty()


func test_a_change_the_outcome_may_not_make_is_dropped() -> void:
	var w: NpcfWorld = _world()
	w.hooks.log_failures = false
	w.pack.intents[&"toy.greet"].hook = load("res://tests/fixtures/hooks/need_change_intent.gd") as Script
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	var queued: NpcfInput = w.inputs[w.inputs.size() - 1]
	assert_int(queued.kind).is_equal(NpcfInput.Kind.CONVERSATION)
	assert_array(queued.changes).is_empty()
	assert_str(str(w.dialogue.records[0].result)).is_equal("toy.friendly")


func test_player_text_never_reaches_state() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "hello hey XYZZY-SECRET", ANA)).is_equal(1)
	w.step()
	w.step()
	assert_bool(w.events.log_text().contains("XYZZY")).is_false()
	for id: StringName in w.npc_ids:
		for r: NpcfMemoryRecord in w.npc(id).memory.records:
			assert_bool(JSON.stringify(r.to_dict()).contains("XYZZY")).is_false()
		for b: NpcfBelief in w.npc(id).beliefs.all():
			assert_bool(str(b.value).contains("XYZZY")).is_false()
