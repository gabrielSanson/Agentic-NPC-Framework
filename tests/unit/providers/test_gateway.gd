extends GdUnitTestSuite
## NpcfProviderGateway against the fake server (C3a section 2.13): health, recheck, one request in flight, the bounded
## queue, replacement by key, refusal, keys, close and lookups.

const KEY_VAR: String = "NPCF_TEST_KEY"
const CHAT: String = "POST /v1/chat/completions"
const HEALTH: String = "GET /v1/models"

var _servers: Array[FakeHttpServer] = []
var _gateways: Array[NpcfProviderGateway] = []


func after_test() -> void:
	for g: NpcfProviderGateway in _gateways:
		g.close()
	_gateways.clear()
	for s: FakeHttpServer in _servers:
		s.stop()
	_servers.clear()
	OS.set_environment(KEY_VAR, "")


func _server(health_code: int = 200) -> FakeHttpServer:
	var s: FakeHttpServer = FakeHttpServer.new()
	assert_int(s.start()).is_equal(OK)
	_servers.append(s)
	s.json_route(HEALTH, health_code, {"data": []})
	return s


func _gw() -> NpcfProviderGateway:
	var g: NpcfProviderGateway = auto_free(NpcfProviderGateway.new())
	_gateways.append(g)
	return g


func _cfg(id: StringName, url: String) -> NpcfProviderConfig:
	return ProviderFixture.chat_config(id, url)


func _chat_spec(body: String = "{}") -> NpcfHttpSpec:
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = HTTPClient.METHOD_POST
	s.path = "/v1/chat/completions"
	s.headers = PackedStringArray(["Content-Type: application/json"])
	s.body = body.to_utf8_buffer()
	return s


## A callback that records "label:status" for each result.
func _label(results: Array[String], label: String) -> Callable:
	return func(r: NpcfHttpResult) -> void: results.append("%s:%s" % [label, str(r.status)])


func _ready_gateway(server: FakeHttpServer, cfg: NpcfProviderConfig) -> NpcfProviderGateway:
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(cfg)).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.is_ready(cfg.id))).is_true()
	return gw


func test_add_goes_checking_then_ready_and_emits_twice() -> void:
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	var states: Array[StringName] = []
	gw.status_changed.connect(func(_id: StringName, state: StringName, _reason: String) -> void: states.append(state))
	assert_int(gw.add_provider(_cfg(&"llm", server.url()))).is_equal(OK)
	assert_str(str(gw.state(&"llm"))).is_equal("checking")
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.is_ready(&"llm"))).is_true()
	assert_array(states).contains_exactly([&"checking", &"ready"])


func test_a_500_health_check_is_down_with_its_reason() -> void:
	var server: FakeHttpServer = _server(500)
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(_cfg(&"llm", server.url()))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.state(&"llm") == &"down")).is_true()
	assert_str(gw.reason(&"llm")).is_equal("health check: http 500")


func test_a_down_provider_is_rechecked_and_becomes_ready() -> void:
	var server: FakeHttpServer = _server(500)
	var cfg: NpcfProviderConfig = _cfg(&"llm", server.url())
	cfg.retry_ms = 1000
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(cfg)).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.state(&"llm") == &"down")).is_true()
	server.json_route(HEALTH, 200, {"data": []})
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.is_ready(&"llm"))).is_true()


func test_an_unknown_adapter_is_refused_and_never_contacted() -> void:
	var server: FakeHttpServer = _server()
	var cfg: NpcfProviderConfig = _cfg(&"llm", server.url())
	cfg.adapter = &"nope"
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(cfg)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(str(gw.state(&"llm"))).is_equal("refused")
	assert_str(gw.reason(&"llm")).is_equal("llm: unknown adapter \"nope\"")
	ProviderFixture.idle(server, gw, 100)
	assert_int(server.requests.size()).is_equal(0)


func test_a_kind_mismatch_is_refused_and_never_contacted() -> void:
	var server: FakeHttpServer = _server()
	var cfg: NpcfProviderConfig = _cfg(&"llm", server.url())
	cfg.kind = NpcfProviderConfig.Kind.CHOOSE
	cfg.use_for = []
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(cfg)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(str(gw.state(&"llm"))).is_equal("refused")
	assert_str(gw.reason(&"llm")).is_equal("llm: adapter \"openai_chat\" does not serve kind CHOOSE")
	ProviderFixture.idle(server, gw, 100)
	assert_int(server.requests.size()).is_equal(0)


func test_a_duplicate_id_gives_already_exists() -> void:
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(_cfg(&"llm", server.url()))).is_equal(OK)
	assert_int(gw.add_provider(_cfg(&"llm", server.url()))).is_equal(ERR_ALREADY_EXISTS)


func test_send_to_a_provider_that_is_not_ready_is_down_at_once() -> void:
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(_cfg(&"llm", server.url()))).is_equal(OK)
	var results: Array[String] = []
	gw.send(&"llm", _chat_spec(), _label(results, "a"))
	assert_array(results).contains_exactly(["a:down"])


func test_queue_keeps_one_request_open_and_answers_busy_when_full() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = server.json_route(CHAT, 200, {"choices": []})
	route.delay_ms = 300
	var cfg: NpcfProviderConfig = _cfg(&"llm", server.url())
	cfg.max_queue = 1
	var gw: NpcfProviderGateway = _ready_gateway(server, cfg)
	var before: int = server.requests.size()
	var results: Array[String] = []
	gw.send(&"llm", _chat_spec(), _label(results, "0"))
	gw.send(&"llm", _chat_spec(), _label(results, "1"))
	gw.send(&"llm", _chat_spec(), _label(results, "2"))
	assert_array(results).contains_exactly(["2:busy"])
	ProviderFixture.idle(server, gw, 100)
	assert_int(server.requests.size() - before).is_equal(1)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() == 3)).is_true()
	assert_array(results).contains_exactly(["2:busy", "0:ok", "1:ok"])


func test_a_queued_request_with_the_same_key_replaces_the_older_one() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = server.json_route(CHAT, 200, {"choices": []})
	route.delay_ms = 100
	var gw: NpcfProviderGateway = _ready_gateway(server, _cfg(&"llm", server.url()))
	var results: Array[String] = []
	gw.send(&"llm", _chat_spec(), _label(results, "A"))
	gw.send(&"llm", _chat_spec(), _label(results, "B"), Callable(), &"k")
	gw.send(&"llm", _chat_spec(), _label(results, "C"), Callable(), &"k")
	assert_array(results).contains_exactly(["B:dropped"])
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() == 3)).is_true()
	assert_array(results).contains_exactly(["B:dropped", "A:ok", "C:ok"])


func test_a_refused_connection_marks_the_provider_down_and_answers_the_queue() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = server.json_route(CHAT, 200, {"choices": []})
	route.delay_ms = 0
	var gw: NpcfProviderGateway = _ready_gateway(server, _cfg(&"llm", server.url()))
	server.stop()
	var results: Array[String] = []
	gw.send(&"llm", _chat_spec(), _label(results, "X"))
	gw.send(&"llm", _chat_spec(), _label(results, "Y"))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() == 2)).is_true()
	assert_array(results).contains_exactly(["Y:down", "X:refused"])
	assert_str(str(gw.state(&"llm"))).is_equal("down")
	assert_str(gw.reason(&"llm")).is_equal("connection refused")


func test_the_key_is_sent_on_health_and_requests_and_never_shown() -> void:
	OS.set_environment(KEY_VAR, "abc123")
	var server: FakeHttpServer = _server()
	server.json_route(CHAT, 200, {"choices": []})
	var cfg: NpcfProviderConfig = _cfg(&"llm", server.url())
	cfg.key_env = KEY_VAR
	var reasons: Array[String] = []
	var gw: NpcfProviderGateway = _gw()
	gw.status_changed.connect(func(_id: StringName, _state: StringName, reason: String) -> void: reasons.append(reason))
	assert_int(gw.add_provider(cfg)).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.is_ready(&"llm"))).is_true()
	var results: Array[String] = []
	gw.send(&"llm", _chat_spec(), _label(results, "a"))
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return results.size() == 1)).is_true()
	assert_array(results).contains_exactly(["a:ok"])
	assert_int(server.requests.size()).is_equal(2)
	assert_str(server.requests[0].headers["authorization"]).is_equal("Bearer abc123")
	assert_str(server.requests[1].headers["authorization"]).is_equal("Bearer abc123")
	assert_bool(gw.reason(&"llm").contains("abc123")).is_false()
	for reason: String in reasons:
		assert_bool(reason.contains("abc123")).is_false()


func test_an_empty_key_variable_keeps_the_provider_down_without_a_request() -> void:
	var server: FakeHttpServer = _server()
	var cfg: NpcfProviderConfig = _cfg(&"llm", server.url())
	cfg.key_env = "NPCF_TEST_UNSET"
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(cfg)).is_equal(OK)
	assert_str(str(gw.state(&"llm"))).is_equal("down")
	assert_str(gw.reason(&"llm")).is_equal("environment variable NPCF_TEST_UNSET is empty")
	ProviderFixture.idle(server, gw, 100)
	assert_int(server.requests.size()).is_equal(0)


func test_close_answers_the_active_and_the_queued_request_once_each() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = server.json_route(CHAT, 200, {"choices": []})
	route.delay_ms = 300
	var gw: NpcfProviderGateway = _ready_gateway(server, _cfg(&"llm", server.url()))
	var results: Array[String] = []
	gw.send(&"llm", _chat_spec(), _label(results, "A"))
	gw.send(&"llm", _chat_spec(), _label(results, "B"))
	gw.close()
	assert_array(results).contains_exactly(["A:down", "B:down"])
	ProviderFixture.idle(server, gw, 400)
	assert_array(results).contains_exactly(["A:down", "B:down"])
	assert_str(str(gw.state(&"llm"))).is_equal("down")


func test_first_ready_for_returns_the_first_ready_provider_with_that_use() -> void:
	var down_server: FakeHttpServer = _server(500)
	var ok_server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	assert_int(gw.add_provider(_cfg(&"a", down_server.url()))).is_equal(OK)
	assert_int(gw.add_provider(_cfg(&"b", ok_server.url()))).is_equal(OK)
	assert_str(str(gw.first_ready_for(&"lines"))).is_equal("")
	assert_bool(ProviderFixture.pump(ok_server, gw, func() -> bool: return gw.is_ready(&"b"))).is_true()
	assert_str(str(gw.first_ready_for(&"lines"))).is_equal("b")
	assert_str(str(gw.first_ready_for(&"intents"))).is_equal("")
	assert_str(str(gw.state(&"nope"))).is_equal("unknown")
