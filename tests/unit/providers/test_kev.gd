extends GdUnitTestSuite
## The Kev choice provider (C3b section 3.6): the request body, the tolerant reply parser, the intent classifier and
## the presentation chooser against a fake server, and the end-to-end path through the runtime. No await: the pump
## loop is synchronous.

const KEV: String = "POST /v1/systemone"
const HEALTH: String = "GET /"
const FIXTURE: String = "res://tests/fixtures/providers/kev_choice.json"

var _servers: Array[FakeHttpServer] = []
var _gateways: Array[NpcfProviderGateway] = []
var _runtimes: Array[NpcfRuntime] = []


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()
	for g: NpcfProviderGateway in _gateways:
		g.close()
	_gateways.clear()
	for s: FakeHttpServer in _servers:
		s.stop()
	_servers.clear()


func _server(health_code: int = 200) -> FakeHttpServer:
	var s: FakeHttpServer = FakeHttpServer.new()
	assert_int(s.start()).is_equal(OK)
	_servers.append(s)
	s.json_route(HEALTH, health_code, {})
	return s


func _gw() -> NpcfProviderGateway:
	var g: NpcfProviderGateway = auto_free(NpcfProviderGateway.new())
	_gateways.append(g)
	return g


func _kev_cfg(url: String) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = &"kev"
	cfg.kind = NpcfProviderConfig.Kind.CHOOSE
	cfg.adapter = &"kev_systemone"
	cfg.base_url = url
	cfg.use_for = [&"intents", &"presentation"]
	return cfg


func _ready_gateway(server: FakeHttpServer, cfg: NpcfProviderConfig) -> NpcfProviderGateway:
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(cfg)).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.is_ready(cfg.id))).is_true()
	return gw


## The fixture reply, read from the JSON file the tests share.
func _fixture() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert_bool(parsed is Dictionary).is_true()
	var d: Dictionary = parsed
	return d


func _reply_body(answers: Dictionary) -> Dictionary:
	return {"answers": answers}


func _body_of(spec: NpcfHttpSpec) -> Dictionary:
	var parsed: Variant = JSON.parse_string(spec.body.get_string_from_utf8())
	assert_bool(parsed is Dictionary).is_true()
	var d: Dictionary = parsed
	return d


## The body of the last request the server recorded on path.
func _last_body(server: FakeHttpServer, key: String) -> Dictionary:
	var found: Dictionary = {}
	for seen: FakeHttpServer.Seen in server.requests:
		if "%s %s" % [seen.method, seen.path] == key:
			var parsed: Variant = JSON.parse_string(seen.body.get_string_from_utf8())
			if parsed is Dictionary:
				found = parsed
	return found


func _count(server: FakeHttpServer, key: String) -> int:
	var n: int = 0
	for seen: FakeHttpServer.Seen in server.requests:
		if "%s %s" % [seen.method, seen.path] == key:
			n += 1
	return n


func _intents() -> Array[NpcfIntentDef]:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var intents: Array[NpcfIntentDef] = []
	for it: NpcfIntentDef in pack.dialogue.intents:
		intents.append(it)
	return intents


func _ctx() -> NpcfDialogueContext:
	var ctx: NpcfDialogueContext = NpcfDialogueContext.new()
	ctx.npc = &"toy.ana"
	ctx.player_text = "hello hey"
	ctx.intent = &"toy.greet"
	return ctx


func _question(id: StringName, options: Array[StringName], descriptions: Dictionary) -> NpcfPresentationQuestionDef:
	var q: NpcfPresentationQuestionDef = NpcfPresentationQuestionDef.new()
	q.id = id
	q.description = "Question %s." % String(id)
	for o: StringName in options:
		q.options.append(o)
	for k: Variant in descriptions.keys():
		var key: StringName = StringName(str(k))
		var text: String = str(descriptions[k])
		q.option_descriptions[key] = text
	return q


func _presentation_questions() -> Array[NpcfPresentationQuestionDef]:
	var emotion: NpcfPresentationQuestionDef = _question(&"toy.emotion",
			[&"toy.calm", &"toy.happy", &"toy.annoyed"], {"toy.happy": "Pleased and warm."})
	var gesture: NpcfPresentationQuestionDef = _question(&"toy.gesture", [&"toy.none", &"toy.wave"], {})
	var questions: Array[NpcfPresentationQuestionDef] = [emotion, gesture]
	return questions


func _choice_answer(option: String, confidence: float) -> Dictionary:
	return {"type": "choice", "choice": option, "confidence": confidence}


# --- build -----------------------------------------------------------------------------------------

func test_build_sends_the_state_the_model_and_one_choice_question_per_question() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var q: NpcfKevAdapter.Question = NpcfKevAdapter.Question.new()
	q.id = &"intent"
	q.instructions = "Pick one."
	q.options = [&"toy.greet", &"toy.ask_news"]
	q.descriptions = ["Greets.", "Asks for news."]
	var questions: Array[NpcfKevAdapter.Question] = [q]
	var cfg: NpcfProviderConfig = _kev_cfg("http://127.0.0.1:8009")
	var spec: NpcfHttpSpec = adapter.build(cfg, "The player says hi.", questions)
	assert_str(spec.path).is_equal("/v1/systemone")
	assert_int(spec.method).is_equal(HTTPClient.METHOD_POST)
	assert_int(spec.timeout_ms).is_equal(2000)
	var d: Dictionary = _body_of(spec)
	assert_str(str(d["model"])).is_equal("kev-latest")
	assert_str(str(d["state"])).is_equal("The player says hi.")
	var qs: Dictionary = d["questions"]
	var qd: Dictionary = qs["intent"]
	assert_str(str(qd["type"])).is_equal("choice")
	assert_str(str(qd["instructions"])).is_equal("Pick one.")
	var criteria: Dictionary = qd["criteria"]
	assert_bool(criteria == {"toy.greet": "Greets.", "toy.ask_news": "Asks for news."}).is_true()


func test_an_empty_description_becomes_the_option_name() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var q: NpcfKevAdapter.Question = NpcfKevAdapter.Question.new()
	q.id = &"intent"
	q.options = [&"toy.greet", &"toy.insult"]
	q.descriptions = ["", "Insults."]
	var questions: Array[NpcfKevAdapter.Question] = [q]
	var d: Dictionary = _body_of(adapter.build(_kev_cfg("http://127.0.0.1:8009"), "s", questions))
	var qs: Dictionary = d["questions"]
	var intent_q: Dictionary = qs["intent"]
	var criteria: Dictionary = intent_q["criteria"]
	assert_bool(criteria == {"toy.greet": "toy.greet", "toy.insult": "Insults."}).is_true()


func test_a_configured_model_is_sent() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var cfg: NpcfProviderConfig = _kev_cfg("http://127.0.0.1:8009")
	cfg.model = "kev-0.8b"
	var questions: Array[NpcfKevAdapter.Question] = []
	var d: Dictionary = _body_of(adapter.build(cfg, "s", questions))
	assert_str(str(d["model"])).is_equal("kev-0.8b")


func test_the_adapter_serves_choose_and_is_named_in_the_registry() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	assert_int(adapter.kind()).is_equal(NpcfProviderConfig.Kind.CHOOSE)
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(_kev_cfg(server.url()))).is_equal(OK)
	assert_bool(gw.adapter(&"kev") is NpcfKevAdapter).is_true()


# --- parse -----------------------------------------------------------------------------------------

func test_parse_reads_the_fixture() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var r: NpcfHttpResult = NpcfHttpResult.make(&"ok", 200, JSON.stringify(_fixture()).to_utf8_buffer(), 85)
	var answers: Dictionary[StringName, NpcfKevAdapter.Choice] = adapter.parse(r)
	assert_bool(answers.has(&"intent")).is_true()
	var choice: NpcfKevAdapter.Choice = answers[&"intent"]
	assert_str(str(choice.option)).is_equal("toy.greet")
	assert_float(choice.confidence).is_equal_approx(0.91, 0.0001)
	assert_int(choice.probabilities.size()).is_equal(2)


func test_the_option_field_is_read_and_confidence_falls_back_to_the_top_probability() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var body: Dictionary = _reply_body({"intent": {"option": "x", "probabilities": {"x": 0.7, "y": 0.3}}})
	var r: NpcfHttpResult = NpcfHttpResult.make(&"ok", 200, JSON.stringify(body).to_utf8_buffer())
	var answers: Dictionary[StringName, NpcfKevAdapter.Choice] = adapter.parse(r)
	var choice: NpcfKevAdapter.Choice = answers[&"intent"]
	assert_str(str(choice.option)).is_equal("x")
	assert_float(choice.confidence).is_equal_approx(0.7, 0.0001)


func test_the_choice_field_alone_gives_confidence_one() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var body: Dictionary = _reply_body({"intent": {"choice": "x"}})
	var r: NpcfHttpResult = NpcfHttpResult.make(&"ok", 200, JSON.stringify(body).to_utf8_buffer())
	var choice: NpcfKevAdapter.Choice = adapter.parse(r)[&"intent"]
	assert_str(str(choice.option)).is_equal("x")
	assert_float(choice.confidence).is_equal(1.0)


func test_an_answer_without_an_option_is_left_out() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var body: Dictionary = _reply_body({"intent": {"confidence": 0.5}, "other": {"answer": "y", "confidence": 0.4}})
	var r: NpcfHttpResult = NpcfHttpResult.make(&"ok", 200, JSON.stringify(body).to_utf8_buffer())
	var answers: Dictionary[StringName, NpcfKevAdapter.Choice] = adapter.parse(r)
	assert_bool(answers.has(&"intent")).is_false()
	assert_str(str((answers[&"other"] as NpcfKevAdapter.Choice).option)).is_equal("y")


func test_non_numeric_probabilities_are_skipped() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	var body: Dictionary = _reply_body({"intent": {"answer": "x", "probabilities": {"x": 0.6, "y": "many", "z": null}}})
	var r: NpcfHttpResult = NpcfHttpResult.make(&"ok", 200, JSON.stringify(body).to_utf8_buffer())
	var choice: NpcfKevAdapter.Choice = adapter.parse(r)[&"intent"]
	assert_int(choice.probabilities.size()).is_equal(1)
	assert_float(choice.confidence).is_equal_approx(0.6, 0.0001)


func test_a_timeout_or_a_refused_reply_gives_nothing() -> void:
	var adapter: NpcfKevAdapter = NpcfKevAdapter.new()
	assert_bool(adapter.parse(NpcfHttpResult.make(&"timeout")).is_empty()).is_true()
	assert_bool(adapter.parse(NpcfHttpResult.make(&"down")).is_empty()).is_true()
	var bad: NpcfHttpResult = NpcfHttpResult.make(&"ok", 200, "not json".to_utf8_buffer())
	assert_bool(adapter.parse(bad).is_empty()).is_true()


# --- intent classifier -----------------------------------------------------------------------------

func test_the_provider_answer_becomes_the_intent() -> void:
	var server: FakeHttpServer = _server()
	server.json_route(KEV, 200, _fixture())
	var gw: NpcfProviderGateway = _ready_gateway(server, _kev_cfg(server.url()))
	var results: Array[NpcfIntentResult] = []
	var classifier: NpcfProviderIntentClassifier = NpcfProviderIntentClassifier.new(gw, &"kev")
	classifier.classify("hello hey", _intents(), _ctx(), func(r: NpcfIntentResult) -> void: results.append(r))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() > 0)).is_true()
	assert_int(results.size()).is_equal(1)
	assert_str(str(results[0].intent)).is_equal("toy.greet")
	assert_float(results[0].confidence).is_equal_approx(0.91, 0.0001)
	assert_str(str(results[0].source)).is_equal("provider")


func test_the_criteria_keys_are_the_toy_intent_ids_in_authored_order() -> void:
	var server: FakeHttpServer = _server()
	server.json_route(KEV, 200, _fixture())
	var gw: NpcfProviderGateway = _ready_gateway(server, _kev_cfg(server.url()))
	var results: Array[NpcfIntentResult] = []
	var intents: Array[NpcfIntentDef] = _intents()
	var classifier: NpcfProviderIntentClassifier = NpcfProviderIntentClassifier.new(gw, &"kev")
	classifier.classify("hello hey", intents, _ctx(), func(r: NpcfIntentResult) -> void: results.append(r))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() > 0)).is_true()
	var sent: Dictionary = _last_body(server, KEV)
	var qs: Dictionary = sent["questions"]
	var intent_q: Dictionary = qs["intent"]
	var criteria: Dictionary = intent_q["criteria"]
	var keys: Array = criteria.keys()
	var expected: Array = []
	for it: NpcfIntentDef in intents:
		expected.append(String(it.id))
	assert_bool(keys == expected).is_true()
	assert_int(keys.size()).is_equal(4)


func test_a_provider_that_is_down_gives_the_keyword_result_and_sends_nothing() -> void:
	var server: FakeHttpServer = _server(500)
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(_kev_cfg(server.url()))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.state(&"kev") == &"down")).is_true()
	var results: Array[NpcfIntentResult] = []
	var classifier: NpcfProviderIntentClassifier = NpcfProviderIntentClassifier.new(gw, &"kev")
	classifier.classify("hello hey", _intents(), _ctx(), func(r: NpcfIntentResult) -> void: results.append(r))
	assert_int(results.size()).is_equal(1)
	assert_str(str(results[0].intent)).is_equal("toy.greet")
	assert_str(str(results[0].source)).is_equal("keyword")
	assert_int(_count(server, KEV)).is_equal(0)


func test_an_unknown_option_gives_the_keyword_result() -> void:
	var server: FakeHttpServer = _server()
	server.json_route(KEV, 200, _reply_body({"intent": {"choice": "nope", "confidence": 0.99}}))
	var gw: NpcfProviderGateway = _ready_gateway(server, _kev_cfg(server.url()))
	var results: Array[NpcfIntentResult] = []
	var classifier: NpcfProviderIntentClassifier = NpcfProviderIntentClassifier.new(gw, &"kev")
	classifier.classify("hello hey", _intents(), _ctx(), func(r: NpcfIntentResult) -> void: results.append(r))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() > 0)).is_true()
	assert_int(results.size()).is_equal(1)
	assert_str(str(results[0].source)).is_equal("keyword")
	assert_str(str(results[0].intent)).is_equal("toy.greet")


func test_a_hanging_route_gives_the_keyword_result_in_time_and_calls_back_once() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = server.json_route(KEV, 200, {})
	route.hang = true
	var cfg: NpcfProviderConfig = _kev_cfg(server.url())
	cfg.timeout_ms = 200
	var gw: NpcfProviderGateway = _ready_gateway(server, cfg)
	var results: Array[NpcfIntentResult] = []
	var classifier: NpcfProviderIntentClassifier = NpcfProviderIntentClassifier.new(gw, &"kev")
	var started: int = Time.get_ticks_msec()
	classifier.classify("hello hey", _intents(), _ctx(), func(r: NpcfIntentResult) -> void: results.append(r))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() > 0, 3000)).is_true()
	assert_int(Time.get_ticks_msec() - started).is_less(2000)
	ProviderFixture.idle(server, gw, 100)
	assert_int(results.size()).is_equal(1)
	assert_str(str(results[0].source)).is_equal("keyword")


# --- presentation chooser --------------------------------------------------------------------------

func test_a_valid_option_is_taken_and_an_invalid_one_gets_the_rule_answer() -> void:
	var server: FakeHttpServer = _server()
	server.json_route(KEV, 200, _reply_body({
		"toy.emotion": _choice_answer("toy.happy", 0.8),
		"toy.gesture": _choice_answer("toy.nope", 0.9),
	}))
	var gw: NpcfProviderGateway = _ready_gateway(server, _kev_cfg(server.url()))
	var questions: Array[NpcfPresentationQuestionDef] = _presentation_questions()
	var answers: Array[Dictionary] = []
	var chooser: NpcfProviderPresentationChooser = NpcfProviderPresentationChooser.new(gw, &"kev")
	chooser.choose(questions, _ctx(), func(a: Dictionary) -> void: answers.append(a))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return answers.size() > 0)).is_true()
	assert_int(answers.size()).is_equal(1)
	assert_str(str(answers[0][&"toy.emotion"])).is_equal("toy.happy")
	assert_str(str(answers[0][&"toy.gesture"])).is_equal(str(NpcfPresentationChooser.rule_answer(questions[1], _ctx())))
	var sent: Dictionary = _last_body(server, KEV)
	var state: String = str(sent["state"])
	assert_bool(state.contains("The player said: \"hello hey\". Intent: toy.greet.")).is_true()


func test_a_provider_that_is_down_gives_the_same_answers_as_the_rule_chooser() -> void:
	var server: FakeHttpServer = _server(500)
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(_kev_cfg(server.url()))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.state(&"kev") == &"down")).is_true()
	var questions: Array[NpcfPresentationQuestionDef] = _presentation_questions()
	var expected: Array[Dictionary] = []
	NpcfPresentationChooser.new().choose(questions, _ctx(), func(a: Dictionary) -> void: expected.append(a))
	var got: Array[Dictionary] = []
	var chooser: NpcfProviderPresentationChooser = NpcfProviderPresentationChooser.new(gw, &"kev")
	chooser.choose(questions, _ctx(), func(a: Dictionary) -> void: got.append(a))
	assert_int(got.size()).is_equal(1)
	assert_bool(got[0] == expected[0]).is_true()
	assert_int(_count(server, KEV)).is_equal(0)


func test_a_newer_turn_replaces_a_waiting_older_one() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = server.json_route(KEV, 200, _reply_body({
		"toy.emotion": _choice_answer("toy.happy", 0.8),
		"toy.gesture": _choice_answer("toy.wave", 0.7),
	}))
	route.delay_ms = 300
	var gw: NpcfProviderGateway = _ready_gateway(server, _kev_cfg(server.url()))
	var questions: Array[NpcfPresentationQuestionDef] = _presentation_questions()
	var expected: Array[Dictionary] = []
	NpcfPresentationChooser.new().choose(questions, _ctx(), func(a: Dictionary) -> void: expected.append(a))
	var results: Array[Dictionary] = []
	var chooser: NpcfProviderPresentationChooser = NpcfProviderPresentationChooser.new(gw, &"kev")
	for i: int in 3:
		chooser.choose(questions, _ctx(), func(a: Dictionary) -> void: results.append(a))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() == 3)).is_true()
	# The second call was replaced while it waited: it got the rule answers at once, so it is first in the list.
	assert_bool(results[0] == expected[0]).is_true()
	assert_str(str(results[1][&"toy.emotion"])).is_equal("toy.happy")
	assert_str(str(results[2][&"toy.gesture"])).is_equal("toy.wave")
	assert_int(_count(server, KEV)).is_equal(2)


# --- end to end through the runtime ----------------------------------------------------------------

func _started() -> NpcfRuntime:
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	_runtimes.append(rt)
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	return rt


func _set_with(configs: Array[NpcfProviderConfig]) -> NpcfProviderSet:
	var providers_set: NpcfProviderSet = NpcfProviderSet.new()
	providers_set.providers = configs
	return providers_set


func _chat_and_kev(server: FakeHttpServer) -> Array[NpcfProviderConfig]:
	var configs: Array[NpcfProviderConfig] = [ProviderFixture.chat_config(&"llm", server.url()), _kev_cfg(server.url())]
	return configs


func test_the_provider_intent_and_presentation_reach_the_npc_line() -> void:
	var server: FakeHttpServer = _server()
	server.json_route("GET /v1/models", 200, {"data": []})
	server.json_route("POST /v1/chat/completions", 200, ProviderFixture.chat_body(ProviderFixture.VALID_LINE))
	server.json_route(KEV, 200, _reply_body({
		"intent": _choice_answer("toy.greet", 0.91),
		"toy.emotion": _choice_answer("toy.happy", 0.8),
		"toy.gesture": _choice_answer("toy.wave", 0.7),
	}))
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with(_chat_and_kev(server)))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool:
		return rt.providers().is_ready(&"llm") and rt.providers().is_ready(&"kev"))).is_true()
	var presentations: Array[Dictionary] = []
	rt.npc_line.connect(func(_npc: StringName, _text: String, _line_id: int, _source: StringName, pres: Dictionary) -> void:
		presentations.append(pres))
	assert_int(rt.player_say("hello hey", &"toy.ana")).is_greater(0)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return presentations.size() > 0)).is_true()
	assert_str(str(presentations[0][&"toy.emotion"])).is_equal("toy.happy")
	assert_str(str(presentations[0][&"toy.gesture"])).is_equal("toy.wave")
	var records: Array[NpcfDialogueTurnRecord] = rt.dialogue_records()
	assert_str(str(records[records.size() - 1].classifier_source)).is_equal("provider")


func test_removing_the_intent_provider_restores_the_keyword_classifier() -> void:
	var server: FakeHttpServer = _server()
	server.json_route("GET /v1/models", 200, {"data": []})
	server.json_route("POST /v1/chat/completions", 200, ProviderFixture.chat_body(ProviderFixture.VALID_LINE))
	server.json_route(KEV, 200, _reply_body({"intent": _choice_answer("toy.insult", 0.9)}))
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with(_chat_and_kev(server)))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool:
		return rt.providers().is_ready(&"llm") and rt.providers().is_ready(&"kev"))).is_true()
	var lines: Array[int] = []
	rt.npc_line.connect(func(_npc: StringName, _text: String, _line_id: int, _source: StringName, _pres: Dictionary) -> void:
		lines.append(1))
	var chat_only: Array[NpcfProviderConfig] = [ProviderFixture.chat_config(&"llm", server.url())]
	assert_int(rt.use_providers(_set_with(chat_only))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(&"llm"))).is_true()
	assert_int(rt.player_say("hello hey", &"toy.ana")).is_greater(0)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return lines.size() > 0)).is_true()
	var records: Array[NpcfDialogueTurnRecord] = rt.dialogue_records()
	assert_str(str(records[records.size() - 1].classifier_source)).is_equal("keyword")
