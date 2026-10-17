extends GdUnitTestSuite
## The line validator (R13.7): each reply is checked in order and stops at the first failure. The table rows are the
## spec's failure cases; a valid reply gives its stripped line, its cited handles and its validated action.

const ANA: StringName = &"toy.ana"
const WAVE: StringName = &"toy.wave"

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## A request with handle f1 (the yard sighting) and the legal action toy.wave.
func _request() -> NpcfDialogueRequest:
	var request: NpcfDialogueRequest = NpcfDialogueRequest.new()
	request.npc = ANA
	request.handles[&"f1"] = NpcfFactRef.make(&"toy.yard", &"toy.sighting", &"f1")
	request.legal_actions = [WAVE] as Array[StringName]
	return request


## A turn context for Ana in a fresh toy world.
func _context() -> NpcfDialogueContext:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	var ctx: NpcfDialogueContext = NpcfDialogueContext.new()
	ctx.world = w
	ctx.npc = ANA
	ctx.player = &"toy.player"
	ctx.dialogue = w.pack.dialogue
	return ctx


func _check(text: String) -> NpcfLineResult:
	return NpcfLineValidator.check(text, _request(), _context())


func test_a_plain_reply_is_ok() -> void:
	var r: NpcfLineResult = _check('{"line":"Hi.","cited_facts":[],"action":null}')
	assert_bool(r.ok).is_true()
	assert_str(r.text).is_equal("Hi.")
	assert_str(str(r.source)).is_equal("llm")
	assert_object(r.action).is_null()
	assert_array(r.validation_failures).is_empty()


func test_a_cited_handle_and_a_legal_action_are_ok() -> void:
	var r: NpcfLineResult = _check('{"line":"Hi.","cited_facts":["f1"],"action":{"id":"toy.wave","args":{}}}')
	assert_bool(r.ok).is_true()
	assert_array(r.cited).contains_exactly([&"f1"])
	assert_object(r.action).is_not_null()
	assert_str(str(r.action.action)).is_equal("toy.wave")


## Each row: reply text, the failure category, and the message that names the row.
func test_each_failure_category_is_reported() -> void:
	var rows: Array[Array] = [
		['not json', "parse", "not json"],
		['{"line":"","cited_facts":[],"action":null}', "schema", "empty line"],
		['{"line":"Hi.","cited_facts":[],"action":null,"x":1}', "schema", "extra key"],
		['{"line":"%s","cited_facts":[],"action":null}' % ("a".repeat(201)), "schema", "201 characters"],
		['{"line":"Check the Internet.","cited_facts":[],"action":null}', "banned", "banned term"],
		['{"line":"Hi.","cited_facts":["f9"],"action":null}', "citation", "unknown handle"],
		['{"line":"Hi.","cited_facts":[],"action":{"id":"toy.work","args":{}}}', "action", "illegal action"],
		['{"line":"Hi.","cited_facts":[],"action":{"id":"toy.wave","args":{"x":1}}}', "action", "unknown action arg"],
	]
	for row: Array in rows:
		var text: String = row[0]
		var category: StringName = row[1]
		var label: String = row[2]
		var r: NpcfLineResult = _check(text)
		assert_bool(r.ok).override_failure_message("%s: expected a failure" % label).is_false()
		assert_str(str(r.failure)).override_failure_message(label).is_equal(str(category))
		assert_array(r.validation_failures).override_failure_message(label).contains_exactly([category])


func test_the_length_limit_is_inclusive() -> void:
	var r: NpcfLineResult = _check('{"line":"%s","cited_facts":[],"action":null}' % ("a".repeat(200)))
	assert_bool(r.ok).is_true()


func test_the_schema_names_the_handles_and_the_legal_actions() -> void:
	var schema: Dictionary = NpcfLineValidator.schema_for(_request(), 200)
	var props: Dictionary = schema["properties"]
	assert_bool(schema["additionalProperties"]).is_false()
	assert_array(schema["required"]).contains_exactly_in_any_order(["action", "cited_facts", "line"])
	var cited: Dictionary = props["cited_facts"]
	assert_array(cited["items"]["enum"]).contains_exactly(["f1"])
