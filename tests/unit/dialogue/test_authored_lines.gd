extends GdUnitTestSuite
## Authored lines: band selection, placeholders, determinism per seed, the one-line-per-turn rule and the p99
## budget for a dialogue turn (R13.4).

const ANA: StringName = &"toy.ana"
const PLAYER: StringName = &"toy.player"
const TRUST: StringName = &"toy.trust"

var _worlds: Array[NpcfWorld] = []
var _lines: Array[Array] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(seed_value: int = 1) -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), seed_value)
	_worlds.append(w)
	_lines.clear()
	w.dialogue.line.connect(func(npc: StringName, text: String, line_id: int, source: StringName, pres: Dictionary) -> void:
		_lines.append([npc, text, line_id, source, pres]))
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(PLAYER, NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w


func _last_text() -> String:
	return str(_lines[_lines.size() - 1][1])


func test_a_trusting_npc_gets_the_trusting_line_and_presentation() -> void:
	var w: NpcfWorld = _world()
	w.relationships.seed_value(w, ANA, PLAYER, TRUST, 40)
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_str(_last_text()).is_equal("Good to see you again, friend.")
	assert_str(str(_lines[0][3])).is_equal("authored")
	var pres: Dictionary = _lines[0][4]
	assert_str(str(pres[&"toy.emotion"])).is_equal("toy.happy")
	assert_str(str(pres[&"toy.gesture"])).is_equal("toy.wave")


func test_a_neutral_npc_gets_one_of_the_general_greetings() -> void:
	var w: NpcfWorld = _world()
	for _i: int in 12:
		assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_greater(0)
	var texts: PackedStringArray = []
	for entry: Array in _lines:
		texts.append(str(entry[1]))
	for text: String in texts:
		assert_bool(["Hello there.", "Hi. I'm Ana."].has(text)).is_true()
	assert_bool(texts.has("Hello there.")).is_true()
	assert_bool(texts.has("Hi. I'm Ana.")).is_true()


func test_the_same_seed_gives_the_same_lines_and_another_seed_differs() -> void:
	var texts: PackedStringArray = []
	for seed_value: int in [1, 1, 2]:
		var w: NpcfWorld = _world(seed_value)
		var run: PackedStringArray = []
		for _i: int in 10:
			assert_int(w.dialogue.begin_turn(w, "work today", ANA)).is_greater(0)
			run.append(_last_text())
		texts.append("\n".join(run))
	assert_str(texts[0]).is_equal(texts[1])
	assert_bool(texts[0] != texts[2]).is_true()


func test_placeholders_are_filled_and_nothing_is_left_over() -> void:
	var w: NpcfWorld = _world()
	var minute: int = w.view(ANA).minute_of_day()
	var clock_text: String = "It is %02d:%02d already." % [minute / 60, minute % 60]
	for _i: int in 20:
		assert_int(w.dialogue.begin_turn(w, "work today", ANA)).is_greater(0)
	for entry: Array in _lines:
		var text: String = entry[1]
		assert_bool(text.contains("{")).is_false()
		assert_bool(text == "Mm, is that so?" or text == clock_text).is_true()


func test_a_dialogue_without_lines_for_the_intent_uses_the_default_lines() -> void:
	var pack: NpcfLoadedPack = DialogueFixture.load_pack()
	pack.dialogue.lines.clear()
	pack.dialogue.default_lines = PackedStringArray(["..."])
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), 1)
	_worlds.append(w)
	_lines.clear()
	w.dialogue.line.connect(func(npc: StringName, text: String, line_id: int, source: StringName, pres: Dictionary) -> void:
		_lines.append([npc, text, line_id, source, pres]))
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(PLAYER, NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	assert_int(w.dialogue.begin_turn(w, "work today", ANA)).is_equal(1)
	assert_str(_last_text()).is_equal("...")


func test_each_turn_gives_exactly_one_line_with_increasing_ids() -> void:
	var w: NpcfWorld = _world()
	var texts: Array[String] = ["hello hey", "you stupid idiot", "seen any news?", "work today", "what's new?"]
	for i: int in 50:
		assert_int(w.dialogue.begin_turn(w, texts[i % texts.size()], ANA)).is_equal(i + 1)
		if i % 20 == 19:
			w.step()
	assert_int(_lines.size()).is_equal(50)
	for i: int in 50:
		assert_int(_lines[i][2]).is_equal(i + 1)


func test_a_turn_stays_within_the_p99_budget() -> void:
	var w: NpcfWorld = _world()
	var texts: Array[String] = ["hello hey", "you stupid idiot", "seen any news?", "work today", "what's new?", "good morning"]
	var micros: Array[int] = []
	for i: int in 1000:
		var t0: int = Time.get_ticks_usec()
		var id: int = w.dialogue.begin_turn(w, texts[i % texts.size()], ANA)
		micros.append(Time.get_ticks_usec() - t0)
		assert_int(id).is_greater(0)
		if i % 20 == 19:
			w.step()
	micros.sort()
	var p50: int = micros[micros.size() / 2]
	var p99: int = micros[int(float(micros.size()) * 0.99)]
	print("dialogue turn: p50 %d us, p99 %d us" % [p50, p99])
	assert_int(p99).is_less_equal(5000)
