extends GdUnitTestSuite
## The keyword classifier on the toy intents, the service's threshold and fallback, and the loader's dialogue checks.

const GREET: StringName = &"toy.greet"
const ASK_NEWS: StringName = &"toy.ask_news"
const INSULT: StringName = &"toy.insult"
const SMALLTALK: StringName = &"toy.smalltalk"
const ANA: StringName = &"toy.ana"

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## Classifies synchronously with the default classifier.
func _classify(text: String) -> NpcfIntentResult:
	var pack: NpcfLoadedPack = DialogueFixture.load_pack()
	var out: Array[NpcfIntentResult] = []
	NpcfKeywordIntentClassifier.new().classify(text, pack.dialogue.intents, null, func(r: NpcfIntentResult) -> void: out.append(r))
	assert_int(out.size()).is_equal(1)
	return out[0]


## Loads a dialogue copy and returns the load result, after `change` edits it.
func _load_with(change: Callable) -> NpcfLoadResult:
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	manifest.dialogue = DialogueFixture.fresh_dialogue()
	change.call(manifest.dialogue)
	return NpcfPackLoader.new().load_pack(manifest)


func _intent(d: NpcfDialogueDef, id: StringName) -> NpcfIntentDef:
	for it: NpcfIntentDef in d.intents:
		if it.id == id:
			return it
	return null


func test_one_of_four_keywords_gives_a_third() -> void:
	var r: NpcfIntentResult = _classify("Hello there!")
	assert_str(str(r.intent)).is_equal(str(GREET))
	assert_float(r.confidence).is_equal_approx(1.0 / 3.0, 0.0001)
	assert_str(str(r.source)).is_equal("keyword")


func test_three_keywords_give_full_confidence() -> void:
	var r: NpcfIntentResult = _classify("hey, hello, good morning")
	assert_str(str(r.intent)).is_equal(str(GREET))
	assert_float(r.confidence).is_equal(1.0)


func test_a_pattern_gives_full_confidence() -> void:
	assert_str(str(_classify("What's new?").intent)).is_equal(str(ASK_NEWS))
	assert_float(_classify("What's new?").confidence).is_equal(1.0)
	assert_str(str(_classify("Whats new").intent)).is_equal(str(ASK_NEWS))
	assert_float(_classify("Whats new").confidence).is_equal(1.0)


func test_a_keyword_inside_a_longer_word_does_not_count() -> void:
	var r: NpcfIntentResult = _classify("purple elephants")
	assert_str(str(r.intent)).is_equal(str(GREET))
	assert_float(r.confidence).is_equal(0.0)


func test_a_tie_goes_to_the_earlier_intent() -> void:
	var r: NpcfIntentResult = _classify("hate news")
	assert_str(str(r.intent)).is_equal(str(ASK_NEWS))
	assert_float(r.confidence).is_equal_approx(1.0 / 3.0, 0.0001)


func test_insult_keywords_match_their_intent() -> void:
	var r: NpcfIntentResult = _classify("you idiot")
	assert_str(str(r.intent)).is_equal(str(INSULT))
	assert_float(r.confidence).is_equal_approx(1.0 / 3.0, 0.0001)


func test_the_service_falls_back_below_the_threshold() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "purple elephants", ANA)).is_equal(1)
	var rec: NpcfDialogueTurnRecord = w.dialogue.records[0]
	assert_str(str(rec.intent)).is_equal(str(SMALLTALK))
	assert_bool(rec.fell_back).is_true()
	assert_float(rec.confidence).is_equal(0.0)


func test_one_third_is_below_the_default_threshold() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "Hello there!", ANA)).is_equal(1)
	var rec: NpcfDialogueTurnRecord = w.dialogue.records[0]
	assert_str(str(rec.intent)).is_equal(str(SMALLTALK))
	assert_bool(rec.fell_back).is_true()


func test_two_keywords_pass_the_threshold() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	var rec: NpcfDialogueTurnRecord = w.dialogue.records[0]
	assert_str(str(rec.intent)).is_equal(str(GREET))
	assert_bool(rec.fell_back).is_false()
	assert_float(rec.confidence).is_equal_approx(2.0 / 3.0, 0.0001)


# --- loader -------------------------------------------------------------------------------------

func test_a_pattern_that_does_not_compile_fails_to_load() -> void:
	var result: NpcfLoadResult = _load_with(func(d: NpcfDialogueDef) -> void:
		_intent(d, ASK_NEWS).patterns = PackedStringArray(["(unclosed"]))
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("does not compile")


func test_a_placeholder_that_is_not_allowed_fails_to_load() -> void:
	var result: NpcfLoadResult = _load_with(func(d: NpcfDialogueDef) -> void:
		d.default_lines = PackedStringArray(["Hi {nope}."]))
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("{nope}")


func test_a_missing_fallback_intent_fails_to_load() -> void:
	var result: NpcfLoadResult = _load_with(func(d: NpcfDialogueDef) -> void:
		d.fallback_intent = null)
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("fallback")


func test_empty_default_lines_fail_to_load() -> void:
	var result: NpcfLoadResult = _load_with(func(d: NpcfDialogueDef) -> void:
		d.default_lines = PackedStringArray())
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("default_lines")


func test_an_undeclared_relationship_dimension_in_an_outcome_fails_to_load() -> void:
	var result: NpcfLoadResult = _load_with(func(d: NpcfDialogueDef) -> void:
		var deltas: Dictionary[StringName, int] = {&"toy.fear": 1}
		_intent(d, GREET).outcome.rel_deltas = deltas)
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("toy.fear")


func test_the_toy_dialogue_loads_cleanly() -> void:
	var result: NpcfLoadResult = _load_with(func(_d: NpcfDialogueDef) -> void: pass)
	assert_str(result.format_errors()).is_equal("")
	assert_bool(result.ok).is_true()


# --- helpers ------------------------------------------------------------------------------------

func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	_move_player(w)
	return w


## The player stands at home_a, so Ana (named in each turn) is in range.
func _move_player(w: NpcfWorld) -> void:
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.player", NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
