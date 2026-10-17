extends GdUnitTestSuite
## Presentation answers: rule answers per line, the default option, and sanitizing of a chooser's reply.

const ANA: StringName = &"toy.ana"
const PLAYER: StringName = &"toy.player"

var _worlds: Array[NpcfWorld] = []
var _lines: Array[Dictionary] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## Answers with a reply that holds one invalid answer and leaves a question out.
class BogusChooser extends NpcfPresentationChooser:
	func choose(_questions: Array[NpcfPresentationQuestionDef], _ctx: NpcfDialogueContext, on_done: Callable) -> void:
		var answers: Dictionary[StringName, StringName] = {&"toy.emotion": &"toy.bogus"}
		on_done.call(answers)


func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	_lines.clear()
	w.dialogue.line.connect(func(_npc: StringName, _text: String, _line_id: int, _source: StringName, pres: Dictionary) -> void:
		_lines.append(pres))
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(PLAYER, NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w


func test_an_insult_gets_an_annoyed_face_and_small_talk_gets_the_default() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "you stupid idiot", ANA)).is_equal(1)
	assert_str(str(_lines[0][&"toy.emotion"])).is_equal("toy.annoyed")
	assert_str(str(_lines[0][&"toy.gesture"])).is_equal("toy.none")
	assert_int(w.dialogue.begin_turn(w, "work today", ANA)).is_equal(2)
	assert_str(str(_lines[1][&"toy.emotion"])).is_equal("toy.calm")
	assert_str(str(_lines[1][&"toy.gesture"])).is_equal("toy.none")


func test_an_invalid_or_missing_answer_is_replaced_by_the_rule_answer() -> void:
	var w: NpcfWorld = _world()
	w.dialogue.chooser = BogusChooser.new()
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_str(str(_lines[0][&"toy.emotion"])).is_equal("toy.happy")
	assert_str(str(_lines[0][&"toy.gesture"])).is_equal("toy.wave")
	assert_int(_lines[0].size()).is_equal(2)
