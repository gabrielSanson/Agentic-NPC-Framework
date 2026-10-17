extends GdUnitTestSuite
## The OpenAI chat adapter: request body, reply parsing, and the end-to-end path through the runtime's line generator
## (C3a section 2.13). The end-to-end tests use the toy pack and a fake server; the fallback is the authored line.

var _servers: Array[FakeHttpServer] = []
var _runtimes: Array[NpcfRuntime] = []


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()
	for s: FakeHttpServer in _servers:
		s.stop()
	_servers.clear()


func _server() -> FakeHttpServer:
	var s: FakeHttpServer = FakeHttpServer.new()
	assert_int(s.start()).is_equal(OK)
	_servers.append(s)
	s.json_route("GET /v1/models", 200, {"data": []})
	return s


func _request(structured: bool) -> NpcfDialogueRequest:
	var req: NpcfDialogueRequest = NpcfDialogueRequest.new()
	var msgs: Array[NpcfChatMessage] = [NpcfChatMessage.make(&"system", "Be brief."), NpcfChatMessage.make(&"user", "hi")]
	req.messages = msgs
	req.temperature = 0.5
	req.max_tokens = 100
	req.structured_output = structured
	req.schema = {"type": "object"}
	return req


func _body_of(spec: NpcfHttpSpec) -> Dictionary:
	var parsed: Variant = JSON.parse_string(spec.body.get_string_from_utf8())
	assert_bool(parsed is Dictionary).is_true()
	var d: Dictionary = parsed
	return d


func _reply(status: StringName, body: PackedByteArray, latency: int = 0) -> NpcfHttpResult:
	return NpcfHttpResult.make(status, 200, body, latency)


func test_build_has_messages_sampling_stream_and_the_json_schema() -> void:
	var adapter: NpcfOpenAiChatAdapter = NpcfOpenAiChatAdapter.new()
	var cfg: NpcfProviderConfig = ProviderFixture.chat_config(&"llm", "http://127.0.0.1:8080")
	var spec: NpcfHttpSpec = adapter.build(cfg, _request(true))
	assert_str(spec.path).is_equal("/v1/chat/completions")
	assert_int(spec.method).is_equal(HTTPClient.METHOD_POST)
	assert_int(spec.timeout_ms).is_equal(8000)
	var d: Dictionary = _body_of(spec)
	var expected_messages: Array = [{"role": "system", "content": "Be brief."}, {"role": "user", "content": "hi"}]
	assert_bool(d["messages"] == expected_messages).is_true()
	var temperature: float = d["temperature"]
	assert_float(temperature).is_equal(0.5)
	var max_tokens: int = d["max_tokens"]
	assert_int(max_tokens).is_equal(100)
	var stream: bool = d["stream"]
	assert_bool(stream).is_false()
	var rf: Dictionary = d["response_format"]
	assert_str(str(rf["type"])).is_equal("json_schema")
	var js: Dictionary = rf["json_schema"]
	var schema: Dictionary = js["schema"]
	assert_bool(schema == {"type": "object"}).is_true()
	assert_bool(d.has("model")).is_false()


func test_model_is_sent_when_the_config_names_one() -> void:
	var adapter: NpcfOpenAiChatAdapter = NpcfOpenAiChatAdapter.new()
	var cfg: NpcfProviderConfig = ProviderFixture.chat_config(&"llm", "http://127.0.0.1:8080")
	cfg.model = "gemma"
	var d: Dictionary = _body_of(adapter.build(cfg, _request(true)))
	assert_str(str(d["model"])).is_equal("gemma")


func test_no_response_format_without_structured_output_or_when_turned_off() -> void:
	var adapter: NpcfOpenAiChatAdapter = NpcfOpenAiChatAdapter.new()
	var cfg: NpcfProviderConfig = ProviderFixture.chat_config(&"llm", "http://127.0.0.1:8080")
	assert_bool(_body_of(adapter.build(cfg, _request(false))).has("response_format")).is_false()
	cfg.extra[&"json_schema"] = false
	assert_bool(_body_of(adapter.build(cfg, _request(true))).has("response_format")).is_false()


func test_a_good_reply_is_ok_with_its_text_and_latency() -> void:
	var adapter: NpcfOpenAiChatAdapter = NpcfOpenAiChatAdapter.new()
	var body: PackedByteArray = JSON.stringify(ProviderFixture.chat_body("hi")).to_utf8_buffer()
	var reply: NpcfLlmReply = adapter.parse(_reply(&"ok", body, 12))
	assert_str(str(reply.status)).is_equal("ok")
	assert_str(reply.text).is_equal("hi")
	assert_int(reply.latency_ms).is_equal(12)


func test_a_reply_without_choices_is_http() -> void:
	var adapter: NpcfOpenAiChatAdapter = NpcfOpenAiChatAdapter.new()
	var reply: NpcfLlmReply = adapter.parse(_reply(&"ok", "{}".to_utf8_buffer()))
	assert_str(str(reply.status)).is_equal("http")


func test_a_timeout_stays_a_timeout_and_a_down_result_is_http() -> void:
	var adapter: NpcfOpenAiChatAdapter = NpcfOpenAiChatAdapter.new()
	var timed: NpcfLlmReply = adapter.parse(NpcfHttpResult.make(&"timeout"))
	assert_str(str(timed.status)).is_equal("timeout")
	var down: NpcfLlmReply = adapter.parse(NpcfHttpResult.make(&"down"))
	assert_str(str(down.status)).is_equal("http")


# --- end to end through the runtime ----------------------------------------------------------------

func _started() -> NpcfRuntime:
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	_runtimes.append(rt)
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	return rt


func _set_with(cfg: NpcfProviderConfig) -> NpcfProviderSet:
	var providers: Array[NpcfProviderConfig] = [cfg]
	var providers_set: NpcfProviderSet = NpcfProviderSet.new()
	providers_set.providers = providers
	return providers_set


func test_a_valid_chat_reply_becomes_the_npc_line() -> void:
	var server: FakeHttpServer = _server()
	server.json_route(
			"POST /v1/chat/completions", 200, ProviderFixture.chat_body(ProviderFixture.VALID_LINE))
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with(ProviderFixture.chat_config(&"llm", server.url())))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(&"llm"))).is_true()
	var lines: Array[Array] = []
	rt.npc_line.connect(func(npc: StringName, text: String, _line_id: int, source: StringName, _pres: Dictionary) -> void:
		lines.append([npc, text, source]))
	assert_int(rt.player_say("hello hey", &"toy.ana")).is_greater(0)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return lines.size() > 0)).is_true()
	assert_int(lines.size()).is_equal(1)
	assert_str(str(lines[0][0])).is_equal("toy.ana")
	assert_str(str(lines[0][1])).is_equal("Hi there, friend.")
	assert_str(str(lines[0][2])).is_equal("llm")


func test_a_chat_request_that_hangs_falls_back_to_the_authored_line() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = server.json_route("POST /v1/chat/completions", 200, {})
	route.hang = true
	var cfg: NpcfProviderConfig = ProviderFixture.chat_config(&"llm", server.url())
	cfg.timeout_ms = 200
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with(cfg))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(&"llm"))).is_true()
	var sources: Array[StringName] = []
	rt.npc_line.connect(func(_npc: StringName, _text: String, _line_id: int, source: StringName, _pres: Dictionary) -> void:
		sources.append(source))
	assert_int(rt.player_say("hello hey", &"toy.ana")).is_greater(0)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return sources.size() > 0)).is_true()
	assert_array(sources).contains_exactly([&"authored"])


func test_a_provider_that_is_down_falls_back_to_the_authored_line_at_once() -> void:
	var server: FakeHttpServer = FakeHttpServer.new()
	assert_int(server.start()).is_equal(OK)
	_servers.append(server)
	server.json_route("GET /v1/models", 500, {})
	var rt: NpcfRuntime = _started()
	var statuses: Array[StringName] = []
	rt.provider_status_changed.connect(func(_id: StringName, state: StringName, _reason: String) -> void:
		statuses.append(state))
	assert_int(rt.use_providers(_set_with(ProviderFixture.chat_config(&"llm", server.url())))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().state(&"llm") == &"down")).is_true()
	assert_array(statuses).contains_exactly([&"checking", &"down"])
	var sources: Array[StringName] = []
	rt.npc_line.connect(func(_npc: StringName, _text: String, _line_id: int, source: StringName, _pres: Dictionary) -> void:
		sources.append(source))
	assert_int(rt.player_say("hello hey", &"toy.ana")).is_greater(0)
	assert_array(sources).contains_exactly([&"authored"])


func test_use_providers_rejects_a_null_set() -> void:
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(null)).is_equal(ERR_INVALID_PARAMETER)
	assert_object(rt.providers()).is_null()
