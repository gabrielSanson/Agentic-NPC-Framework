extends GdUnitTestSuite
## Provider call records (C5c 5.2): one record per request, no headers, and the prompt only when the project setting
## npcf/debug/trace_prompts is on. Uses the fake HTTP server and an openai_chat provider through the runtime.

const ANA: StringName = &"toy.ana"
const VALID_LINE: String = '{"line":"Hi there, friend.","cited_facts":[],"action":null}'

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
	s.json_route("POST /v1/chat/completions", 200, ProviderFixture.chat_body(VALID_LINE))
	return s


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


## Starts a runtime whose line provider is the fake server, waits until it is ready, and asks one question.
func _one_request(server: FakeHttpServer, trace_prompts: bool) -> NpcfRuntime:
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with(ProviderFixture.chat_config(&"llm", server.url())))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(&"llm"))).is_true()
	rt.providers().trace_prompts = trace_prompts
	var lines: Array[String] = []
	rt.npc_line.connect(func(_npc: StringName, text: String, _line_id: int, _source: StringName, _pres: Dictionary) -> void:
		lines.append(text))
	assert_int(rt.player_say("hello hey", ANA)).is_greater(0)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return lines.size() > 0)).is_true()
	return rt


func test_one_request_gives_one_record_without_prompt() -> void:
	var server: FakeHttpServer = _server()
	var rt: NpcfRuntime = _one_request(server, false)
	var calls: Array[NpcfProviderCallRecord] = rt.providers().calls
	assert_int(calls.size()).is_equal(1)
	var rec: NpcfProviderCallRecord = calls[0]
	assert_str(str(rec.provider)).is_equal("llm")
	assert_str(str(rec.kind)).is_equal("generate")
	assert_str(str(rec.status)).is_equal("ok")
	assert_bool(rec.fell_back).is_false()
	assert_str(rec.prompt).is_empty()
	var traced: Dictionary = rt.trace(ANA)
	var providers: Array = traced["providers"]
	assert_int(providers.size()).is_equal(1)


func test_one_request_with_prompt_tracing_keeps_the_prompt_text() -> void:
	var server: FakeHttpServer = _server()
	var rt: NpcfRuntime = _one_request(server, true)
	var calls: Array[NpcfProviderCallRecord] = rt.providers().calls
	assert_int(calls.size()).is_equal(1)
	assert_str(calls[0].prompt).is_not_empty()
	assert_bool(calls[0].prompt.contains("messages")).is_true()


func test_no_record_holds_a_key_or_a_header() -> void:
	var server: FakeHttpServer = _server()
	var rt: NpcfRuntime = _one_request(server, true)
	var text: String = ""
	for rec: NpcfProviderCallRecord in rt.providers().calls:
		text += JSON.stringify(rec.to_dict())
	assert_bool(text.contains("Authorization")).is_false()
	assert_bool(text.contains("Bearer ")).is_false()
