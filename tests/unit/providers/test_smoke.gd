extends GdUnitTestSuite
## C6c (section 4.5): NpcfSmoke.run against one fake server that plays all four model roles, with the toy pack.
## The breeze route is non-commercial, so the project setting is set for each test and restored after it.

const CHAT: String = "POST /v1/chat/completions"
const KEV: String = "POST /v1/systemone"
const TRANSCRIBE: String = "POST /v1/audio/transcriptions"
const SPEECH: String = "POST /v1/audio/speech"
const HEALTH_ROOT: String = "GET /"
const MODELS: String = "GET /v1/models"
const HEALTH_STT: String = "GET /health"
const NPC: StringName = &"toy.ana"
const ALLOW_SETTING: String = "npcf/providers/allow_non_commercial"
const MAX_MS: int = 3000

var _server: FakeHttpServer = null
var _runtimes: Array[NpcfRuntime] = []


func before_test() -> void:
	_server = FakeHttpServer.new()
	assert_int(_server.start()).is_equal(OK)
	_server.json_route(HEALTH_ROOT, 200, {})
	_server.json_route(MODELS, 200, {"data": []})
	_server.json_route(HEALTH_STT, 200, {})
	_server.json_route(CHAT, 200, ProviderFixture.chat_body(ProviderFixture.VALID_LINE))
	_server.json_route(KEV, 200, _kev_body())
	_server.json_route(TRANSCRIBE, 200, {"text": "hello there"})
	_speech(false)


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()
	if _server != null:
		_server.stop()
	ProjectSettings.set_setting(ALLOW_SETTING, false)


func _kev_body() -> Dictionary:
	return {"answers": {
		"intent": {"type": "choice", "choice": "toy.greet", "confidence": 0.9,
				"probabilities": {"toy.greet": 0.9, "toy.ask_news": 0.1}},
		"toy.emotion": {"type": "choice", "choice": "toy.calm"},
		"toy.gesture": {"type": "choice", "choice": "toy.none"},
	}}


func _speech(cut_short: bool) -> void:
	var route: FakeHttpServer.Route = FakeHttpServer.Route.new()
	var piece: PackedByteArray = PackedByteArray()
	piece.resize(4800)
	route.chunks = [piece, piece, piece]
	route.chunked = true
	route.cut_short = cut_short
	_server.routes[SPEECH] = route


func _cfg(id: StringName, kind: NpcfProviderConfig.Kind, adapter: StringName, uses: Array[StringName],
		license: NpcfProviderConfig.License = NpcfProviderConfig.License.OPEN) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = id
	cfg.kind = kind
	cfg.adapter = adapter
	cfg.base_url = _server.url()
	cfg.use_for = uses
	cfg.license_use = license
	return cfg


func _all_four() -> Array[NpcfProviderConfig]:
	var configs: Array[NpcfProviderConfig] = []
	configs.append(ProviderFixture.chat_config(&"llm", _server.url()))
	configs.append(_cfg(&"kev", NpcfProviderConfig.Kind.CHOOSE, &"kev_systemone", [&"intents", &"presentation"]))
	configs.append(_cfg(&"stt", NpcfProviderConfig.Kind.TRANSCRIBE, &"openai_transcribe", [&"voice_in"]))
	configs.append(_cfg(&"tts", NpcfProviderConfig.Kind.SPEAK, &"breeze_speech", [&"voice_out"],
			NpcfProviderConfig.License.NON_COMMERCIAL))
	return configs


func _run(configs: Array[NpcfProviderConfig], wav: PackedByteArray = PackedByteArray()) -> NpcfSmoke.Report:
	ProjectSettings.set_setting(ALLOW_SETTING, true)
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	_runtimes.append(rt)
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	var providers_set: NpcfProviderSet = NpcfProviderSet.new()
	providers_set.providers = configs
	assert_int(rt.use_providers(providers_set)).is_equal(OK)
	return NpcfSmoke.run(rt, NPC, "Hi there.", wav, MAX_MS, _server.poll)


func _step(report: NpcfSmoke.Report, name: StringName) -> NpcfSmoke.Step:
	for s: NpcfSmoke.Step in report.steps:
		if s.name == name:
			return s
	return null


func test_with_all_four_working_every_step_is_ok() -> void:
	var report: NpcfSmoke.Report = _run(_all_four())
	assert_bool(report.ok()).is_true()
	for name: StringName in [&"providers", &"voice_out", &"voice_in", &"intents", &"presentation", &"lines"]:
		var s: NpcfSmoke.Step = _step(report, name)
		assert_object(s).is_not_null()
		assert_bool(s.ok).is_true()
	assert_str(_step(report, &"intents").detail).starts_with("provider (toy.greet")
	assert_str(_step(report, &"lines").detail).is_equal(ProviderFixture.VALID_LINE.split('"')[3])
	var sent: int = -1
	for seen: FakeHttpServer.Seen in _server.requests:
		if seen.method == "POST" and seen.path == "/v1/audio/transcriptions":
			sent = seen.body.size()
	assert_bool(sent > 44).is_true()


func test_a_kev_500_fails_intents_as_keyword_fallback() -> void:
	_server.json_route(KEV, 500, {})
	var report: NpcfSmoke.Report = _run(_all_four())
	assert_bool(report.ok()).is_false()
	var s: NpcfSmoke.Step = _step(report, &"intents")
	assert_bool(s.ok).is_false()
	assert_str(s.detail).contains("keyword fallback")


func test_an_invalid_chat_reply_fails_lines() -> void:
	_server.routes[CHAT] = FakeHttpServer.Route.new()
	_server.routes[CHAT].body = "not json".to_utf8_buffer()
	var report: NpcfSmoke.Report = _run(_all_four())
	assert_bool(report.ok()).is_false()
	assert_bool(_step(report, &"lines").ok).is_false()


func test_a_cut_speech_reply_is_ok_with_the_cut_detail() -> void:
	_speech(true)
	var report: NpcfSmoke.Report = _run(_all_four())
	var s: NpcfSmoke.Step = _step(report, &"voice_out")
	assert_bool(s.ok).is_true()
	assert_str(s.detail).contains("reported as cut")
	assert_bool(_step(report, &"voice_in").ok).is_true()


func test_a_chat_only_set_skips_the_voice_and_choice_steps() -> void:
	var configs: Array[NpcfProviderConfig] = [ProviderFixture.chat_config(&"llm", _server.url())]
	var report: NpcfSmoke.Report = _run(configs)
	assert_bool(report.ok()).is_true()
	for name: StringName in [&"voice_out", &"voice_in", &"intents", &"presentation"]:
		var s: NpcfSmoke.Step = _step(report, name)
		assert_bool(s.ok).is_true()
		assert_str(s.detail).is_equal("skipped: no provider")
	assert_bool(_step(report, &"lines").ok).is_true()
