extends GdUnitTestSuite
## The LLM line generator with the fake transport (R13.5-R13.8): a valid reply is the line, every failure category
## falls back to the authored line, a deferred reply emits nothing until it arrives, and the generated line never
## becomes state.

const ANA: StringName = &"toy.ana"
const GREET: StringName = &"toy.greet"
const VALID: String = '{"line":"Hi there, friend.","cited_facts":[],"action":null}'

var _worlds: Array[NpcfWorld] = []
var _lines: Array[Array] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## The toy world with the player at Ana's house, Ana's line generator wired to a fresh fake transport, and every
## emitted line collected in _lines.
func _world(transport: NpcfFakeLlmTransport) -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	_lines.clear()
	w.dialogue.generator = NpcfLlmLineGenerator.new(transport)
	w.dialogue.line.connect(func(npc: StringName, text: String, line_id: int, source: StringName, _pres: Dictionary) -> void:
		_lines.append([npc, text, line_id, source]))
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.player", NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w


## Every neutral line the pack gives to a greeting that was friendly.
func _greet_lines(w: NpcfWorld) -> PackedStringArray:
	var out: PackedStringArray = []
	for ls: NpcfDialogueLineSet in w.pack.dialogue.lines:
		if ls.intent != null and ls.intent.id == GREET and ls.result == &"toy.friendly" and ls.band == &"":
			out.append_array(ls.lines)
	return out


func _reply(status: StringName, text: String) -> NpcfLlmReply:
	return NpcfLlmReply.make(status, text, 12)


func test_a_valid_reply_is_the_line_and_fills_the_record() -> void:
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	transport.replies.append(_reply(&"ok", VALID))
	var w: NpcfWorld = _world(transport)
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_int(_lines.size()).is_equal(1)
	assert_str(str(_lines[0][1])).is_equal("Hi there, friend.")
	assert_str(str(_lines[0][3])).is_equal("llm")

	var rec: NpcfDialogueTurnRecord = w.dialogue.records[0]
	assert_str(str(rec.llm_status)).is_equal("ok")
	assert_str(str(rec.line_source)).is_equal("llm")
	assert_str(str(rec.variant)).is_equal("toy.default")
	assert_int(rec.latency_ms).is_equal(12)
	assert_array(rec.offered_actions).contains_exactly([&"toy.wave"])
	assert_int(transport.requests.size()).is_equal(1)
	var user: String = ""
	for m: NpcfChatMessage in transport.requests[0].messages:
		if m.role == &"user":
			user = m.content
	assert_str(user).contains("hello hey")


## Each failing reply falls back to exactly one authored line, and the record names the category.
func test_each_failure_category_falls_back_to_the_authored_line() -> void:
	var rows: Array[Array] = [
		[&"timeout", "", &"timeout"],
		[&"http", "", &"http"],
		[&"ok", "not json", &"parse"],
		[&"ok", '{"line":"","cited_facts":[],"action":null}', &"schema"],
		[&"ok", '{"line":"Check the internet.","cited_facts":[],"action":null}', &"banned"],
		[&"ok", '{"line":"Hi.","cited_facts":["f9"],"action":null}', &"citation"],
		[&"ok", '{"line":"Hi.","cited_facts":[],"action":{"id":"toy.work","args":{}}}', &"action"],
	]
	for row: Array in rows:
		var status: StringName = row[0]
		var text: String = row[1]
		var category: StringName = row[2]
		var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
		transport.replies.append(_reply(status, text))
		var w: NpcfWorld = _world(transport)
		assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).override_failure_message(str(category)).is_equal(1)
		assert_int(_lines.size()).override_failure_message("%s: exactly one line" % category).is_equal(1)
		assert_str(str(_lines[0][3])).override_failure_message(str(category)).is_equal("authored")
		assert_bool(_greet_lines(w).has(str(_lines[0][1]))).override_failure_message(str(category)).is_true()
		assert_str(str(w.dialogue.records[0].failure)).override_failure_message(str(category)).is_equal(str(category))
		assert_str(str(w.dialogue.records[0].line_source)).is_equal("authored")


func test_nothing_is_emitted_until_a_deferred_reply_arrives() -> void:
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	transport.deferred = true
	transport.replies.append(_reply(&"ok", VALID))
	var w: NpcfWorld = _world(transport)
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_array(_lines).is_empty()
	w.step()
	assert_array(_lines).is_empty()
	transport.flush()
	assert_int(_lines.size()).is_equal(1)
	assert_str(str(_lines[0][1])).is_equal("Hi there, friend.")


func test_the_generated_line_never_becomes_state() -> void:
	const ZEBRA: String = '{"line":"ZEBRA-LINE-42","cited_facts":[],"action":null}'
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	transport.replies.append(_reply(&"ok", ZEBRA))
	var w: NpcfWorld = _world(transport)
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_str(str(_lines[0][1])).is_equal("ZEBRA-LINE-42")
	w.step()
	w.step()
	assert_str(w.events.log_text()).not_contains("ZEBRA")
	for b: NpcfBelief in w.npc(ANA).beliefs.all():
		assert_str(str(b.to_dict())).not_contains("ZEBRA")
	for r: NpcfMemoryRecord in w.npc(ANA).memory.records:
		assert_str(str(r.to_dict())).not_contains("ZEBRA")
	for e: NpcfEvent in w.events.log:
		if e.kind == NpcfFramework.CONVERSATION:
			for k: StringName in e.payload:
				assert_bool(k == &"intent" or k == &"result" or k == &"facts").is_true()


func test_no_template_falls_back_to_the_authored_line() -> void:
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	var w: NpcfWorld = _world(transport)
	w.pack.dialogue.default_template = null
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_int(transport.requests.size()).is_equal(0)
	assert_str(str(w.dialogue.records[0].failure)).is_equal("no_template")
	assert_int(_lines.size()).is_equal(1)
	assert_str(str(_lines[0][3])).is_equal("authored")


func test_a_reply_after_dispose_emits_nothing() -> void:
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	transport.deferred = true
	transport.replies.append(_reply(&"ok", VALID))
	var w: NpcfWorld = _world(transport)
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	w.dialogue.dispose()
	transport.flush()
	assert_array(_lines).is_empty()
