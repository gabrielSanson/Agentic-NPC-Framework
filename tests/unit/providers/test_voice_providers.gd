extends GdUnitTestSuite
## C3c (section 4.7): the WAV and multipart encoders, transcription and streamed speech through the runtime against a
## fake server, truncated speech replies, and the non-commercial gate. No await: the pump loop is synchronous. The
## runtime tests set the project setting for the gate before use_providers, because the runtime creates its gateway
## there; it is restored after each test.

const TRANSCRIBE: String = "POST /v1/audio/transcriptions"
const SPEECH: String = "POST /v1/audio/speech"
const STT_ID: StringName = &"stt"
const TTS_ID: StringName = &"tts"
const ALLOW_SETTING: String = "npcf/providers/allow_non_commercial"

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
	ProjectSettings.set_setting(ALLOW_SETTING, false)


func _server() -> FakeHttpServer:
	var s: FakeHttpServer = FakeHttpServer.new()
	assert_int(s.start()).is_equal(OK)
	_servers.append(s)
	s.json_route("GET /health", 200, {})
	s.json_route("GET /", 200, {})
	return s


func _stt_cfg(url: String) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = STT_ID
	cfg.kind = NpcfProviderConfig.Kind.TRANSCRIBE
	cfg.adapter = &"openai_transcribe"
	cfg.base_url = url
	cfg.use_for = [&"voice_in"]
	return cfg


func _tts_cfg(url: String, license: NpcfProviderConfig.License = NpcfProviderConfig.License.OPEN) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = TTS_ID
	cfg.kind = NpcfProviderConfig.Kind.SPEAK
	cfg.adapter = &"breeze_speech"
	cfg.base_url = url
	cfg.license_use = license
	cfg.use_for = [&"voice_out"]
	return cfg


func _set_with(configs: Array[NpcfProviderConfig]) -> NpcfProviderSet:
	var providers_set: NpcfProviderSet = NpcfProviderSet.new()
	providers_set.providers = configs
	return providers_set


func _started() -> NpcfRuntime:
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	_runtimes.append(rt)
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	return rt


func _gw() -> NpcfProviderGateway:
	var g: NpcfProviderGateway = auto_free(NpcfProviderGateway.new())
	_gateways.append(g)
	return g


func _count(server: FakeHttpServer, key: String) -> int:
	var n: int = 0
	for seen: FakeHttpServer.Seen in server.requests:
		if "%s %s" % [seen.method, seen.path] == key:
			n += 1
	return n


func _speech_route(server: FakeHttpServer, chunks: Array[PackedByteArray], gap_ms: int = 0) -> FakeHttpServer.Route:
	var route: FakeHttpServer.Route = FakeHttpServer.Route.new()
	route.chunks = chunks
	route.chunk_gap_ms = gap_ms
	server.routes[SPEECH] = route
	return route


## Callables for speak(): collect the pieces, collect the final status, or drop the pieces.
func _collect(into: Array[PackedByteArray]) -> Callable:
	return func(pcm: PackedByteArray) -> void: into.append(pcm)


func _status_into(into: Array[StringName]) -> Callable:
	return func(status: StringName) -> void: into.append(status)


func _discard() -> Callable:
	return func(_pcm: PackedByteArray) -> void: pass


## The body of the n-th speech request (health checks are requests too, so they are skipped).
func _speech_body(server: FakeHttpServer, n: int) -> String:
	var found: Array[FakeHttpServer.Seen] = []
	for seen: FakeHttpServer.Seen in server.requests:
		if "%s %s" % [seen.method, seen.path] == SPEECH:
			found.append(seen)
	return found[n].body.get_string_from_ascii()


## True when the bytes hold text (a byte search: a WAV header has zero bytes, which a string conversion would cut at).
func _has(bytes: PackedByteArray, text: String) -> bool:
	var needle: PackedByteArray = text.to_utf8_buffer()
	for i: int in range(0, bytes.size() - needle.size() + 1):
		if bytes.slice(i, i + needle.size()) == needle:
			return true
	return false


func _joined(pieces: Array[PackedByteArray]) -> PackedByteArray:
	var all: PackedByteArray = PackedByteArray()
	for piece: PackedByteArray in pieces:
		all.append_array(piece)
	return all


# --- encoders --------------------------------------------------------------------------------------

func test_wav_header_is_44_bytes_with_the_exact_fields() -> void:
	var wav: PackedByteArray = NpcfWav.encode_pcm16(PackedByteArray([1, 2, 3, 4]), 16000, 1)
	assert_int(wav.size()).is_equal(48)
	assert_str(wav.slice(0, 4).get_string_from_ascii()).is_equal("RIFF")
	assert_int(wav.decode_u32(4)).is_equal(40)
	assert_str(wav.slice(8, 16).get_string_from_ascii()).is_equal("WAVEfmt ")
	assert_int(wav.decode_u32(16)).is_equal(16)
	assert_int(wav.decode_u16(20)).is_equal(1)
	assert_int(wav.decode_u16(22)).is_equal(1)
	assert_int(wav.decode_u32(24)).is_equal(16000)
	assert_int(wav.decode_u32(28)).is_equal(32000)
	assert_int(wav.decode_u16(32)).is_equal(2)
	assert_int(wav.decode_u16(34)).is_equal(16)
	assert_str(wav.slice(36, 40).get_string_from_ascii()).is_equal("data")
	assert_int(wav.decode_u32(40)).is_equal(4)
	assert_bool(wav.slice(44, 48) == PackedByteArray([1, 2, 3, 4])).is_true()


func test_multipart_field_and_finish_are_the_exact_bytes() -> void:
	var body: PackedByteArray = NpcfMultipart.field("B", "text", "hello")
	body.append_array(NpcfMultipart.finish("B"))
	var want: String = "--B\r\nContent-Disposition: form-data; name=\"text\"\r\n\r\nhello\r\n--B--\r\n"
	assert_bool(body == want.to_utf8_buffer()).is_true()
	assert_str(NpcfMultipart.content_type("B")).is_equal("multipart/form-data; boundary=B")


func test_multipart_file_part_has_its_filename_and_type() -> void:
	var part: String = NpcfMultipart.file("B", "file", "audio.wav", "audio/wav", PackedByteArray([9])).get_string_from_ascii()
	assert_bool(part.begins_with("--B\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")).is_true()
	assert_bool(part.contains("\r\nContent-Type: audio/wav\r\n\r\n")).is_true()


# --- transcription -----------------------------------------------------------------------------------

func test_transcribe_returns_the_text_and_sends_a_wav_multipart_body() -> void:
	var server: FakeHttpServer = _server()
	server.json_route(TRANSCRIBE, 200, {"text": "hello there"})
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_stt_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(STT_ID))).is_true()
	var texts: Array[String] = []
	var statuses: Array[StringName] = []
	rt.transcribe(PackedByteArray([1, 2, 3, 4]), func(text: String, status: StringName) -> void:
		texts.append(text)
		statuses.append(status))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return texts.size() == 1)).is_true()
	assert_str(texts[0]).is_equal("hello there")
	assert_str(str(statuses[0])).is_equal("ok")
	var seen: FakeHttpServer.Seen = server.requests[server.requests.size() - 1]
	assert_bool(_has(seen.body, "name=\"file\"")).is_true()
	assert_bool(_has(seen.body, "filename=\"audio.wav\"")).is_true()
	assert_bool(_has(seen.body, "RIFF")).is_true()
	assert_bool(_has(seen.body, "name=\"response_format\"")).is_true()
	assert_bool(seen.headers["content-type"].begins_with("multipart/form-data; boundary=npcf")).is_true()


func test_transcribe_without_a_provider_is_off_at_once() -> void:
	var rt: NpcfRuntime = _started()
	var got: Array[StringName] = []
	rt.transcribe(PackedByteArray([1, 2]), func(text: String, status: StringName) -> void:
		assert_str(text).is_equal("")
		got.append(status))
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0])).is_equal("off")


func test_a_500_transcription_is_http_with_empty_text() -> void:
	var server: FakeHttpServer = _server()
	server.json_route(TRANSCRIBE, 500, {"error": "boom"})
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_stt_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(STT_ID))).is_true()
	var texts: Array[String] = []
	var statuses: Array[StringName] = []
	rt.transcribe(PackedByteArray([1, 2]), func(text: String, status: StringName) -> void:
		texts.append(text)
		statuses.append(status))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return texts.size() == 1)).is_true()
	assert_str(texts[0]).is_equal("")
	assert_str(str(statuses[0])).is_equal("http")


# --- speech, streamed --------------------------------------------------------------------------------

func test_speak_streams_whole_samples_in_order() -> void:
	var server: FakeHttpServer = _server()
	var chunks: Array[PackedByteArray] = [PackedByteArray([1, 2, 3]), PackedByteArray([4, 5]), PackedByteArray([6])]
	_speech_route(server, chunks, 20)
	ProjectSettings.set_setting(ALLOW_SETTING, true)
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_tts_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(TTS_ID))).is_true()
	var outputs: Array[PackedByteArray] = []
	var events: Array[String] = []
	var statuses: Array[StringName] = []
	var on_chunk: Callable = func(pcm: PackedByteArray) -> void:
		outputs.append(pcm)
		events.append("chunk")
	var on_done: Callable = func(status: StringName) -> void:
		events.append("done")
		statuses.append(status)
	rt.speak("hello", "warm", "v1", on_chunk, on_done)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return statuses.size() == 1)).is_true()
	assert_bool(_joined(outputs) == PackedByteArray([1, 2, 3, 4, 5, 6])).is_true()
	for out: PackedByteArray in outputs:
		assert_int(out.size() % 2).is_equal(0)
	assert_bool(events.find("done") >= 2).is_true()
	assert_str(str(statuses[0])).is_equal("ok")


func test_speak_body_has_text_instruction_and_voice_in_order_and_skips_an_empty_instruction() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = FakeHttpServer.Route.new()
	route.body = PackedByteArray([1, 2])
	server.routes[SPEECH] = route
	ProjectSettings.set_setting(ALLOW_SETTING, true)
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_tts_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(TTS_ID))).is_true()
	var done: Array[StringName] = []
	rt.speak("hello", "warm", "v1", _discard(), _status_into(done))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return done.size() == 1)).is_true()
	rt.speak("hi", "", "", _discard(), _status_into(done))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return done.size() == 2)).is_true()
	var first: String = _speech_body(server, 0)
	var at_text: int = first.find("name=\"text\"")
	var at_instruction: int = first.find("name=\"instruction\"")
	var at_voice: int = first.find("name=\"voice_id\"")
	assert_bool(at_text >= 0 and at_text < at_instruction and at_instruction < at_voice).is_true()
	var second: String = _speech_body(server, 1)
	assert_bool(second.contains("name=\"text\"")).is_true()
	assert_bool(second.contains("name=\"instruction\"")).is_false()
	assert_bool(second.contains("name=\"voice_id\"")).is_false()


func test_a_wav_header_is_stripped_across_pieces() -> void:
	var server: FakeHttpServer = _server()
	var header: PackedByteArray = "RIFF".to_ascii_buffer()
	header.resize(44)
	var chunks: Array[PackedByteArray] = [header.slice(0, 10), header.slice(10, 44), PackedByteArray([7, 8])]
	_speech_route(server, chunks)
	ProjectSettings.set_setting(ALLOW_SETTING, true)
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_tts_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(TTS_ID))).is_true()
	var outputs: Array[PackedByteArray] = []
	var done: Array[StringName] = []
	rt.speak("hello", "", "", _collect(outputs), _status_into(done))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return done.size() == 1)).is_true()
	assert_bool(_joined(outputs) == PackedByteArray([7, 8])).is_true()
	assert_str(str(done[0])).is_equal("ok")


func test_a_speech_reply_cut_short_of_its_length_keeps_the_samples_and_ends_as_http() -> void:
	var server: FakeHttpServer = _server()
	var chunks: Array[PackedByteArray] = [PackedByteArray([1, 2, 3, 4]), PackedByteArray([5, 6])]
	var route: FakeHttpServer.Route = _speech_route(server, chunks, 20)
	route.declared_length = 10
	ProjectSettings.set_setting(ALLOW_SETTING, true)
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_tts_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(TTS_ID))).is_true()
	var outputs: Array[PackedByteArray] = []
	var done: Array[StringName] = []
	rt.speak("hello", "", "", _collect(outputs), _status_into(done))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return done.size() == 1)).is_true()
	assert_bool(_joined(outputs) == PackedByteArray([1, 2, 3, 4, 5, 6])).is_true()
	assert_str(str(done[0])).is_equal("http")


func test_a_chunked_speech_reply_cut_before_its_end_ends_as_http() -> void:
	var server: FakeHttpServer = _server()
	var chunks: Array[PackedByteArray] = [PackedByteArray([1, 2]), PackedByteArray([3, 4])]
	var route: FakeHttpServer.Route = _speech_route(server, chunks, 20)
	route.chunked = true
	route.cut_short = true
	ProjectSettings.set_setting(ALLOW_SETTING, true)
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_tts_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(TTS_ID))).is_true()
	var outputs: Array[PackedByteArray] = []
	var done: Array[StringName] = []
	rt.speak("hello", "", "", _collect(outputs), _status_into(done))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return done.size() == 1)).is_true()
	assert_bool(_joined(outputs) == PackedByteArray([1, 2, 3, 4])).is_true()
	assert_str(str(done[0])).is_equal("http")


func test_speak_without_a_provider_is_off_at_once() -> void:
	var rt: NpcfRuntime = _started()
	var done: Array[StringName] = []
	rt.speak("hello", "", "", _discard(), _status_into(done))
	assert_int(done.size()).is_equal(1)
	assert_str(str(done[0])).is_equal("off")


# --- the non-commercial gate ---------------------------------------------------------------------------

func test_license_refusal_gives_the_three_exact_strings_and_empty_when_allowed() -> void:
	var open: NpcfProviderConfig = NpcfProviderConfig.new()
	open.adapter = &"openai_chat"
	var nc: NpcfProviderConfig = NpcfProviderConfig.new()
	nc.adapter = &"openai_chat"
	nc.license_use = NpcfProviderConfig.License.NON_COMMERCIAL
	assert_str(NpcfProviderGateway.license_refusal(open, false, false)).is_equal("")
	assert_str(NpcfProviderGateway.license_refusal(nc, false, true)).is_equal(
		"non-commercial weights are refused in release builds")
	assert_str(NpcfProviderGateway.license_refusal(nc, false, false)).is_equal(
		"non-commercial weights need the project setting npcf/providers/allow_non_commercial = true")
	assert_str(NpcfProviderGateway.license_refusal(nc, true, false)).is_equal("")


func test_a_breeze_provider_without_allow_is_refused_and_never_contacted() -> void:
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	gw.allow_non_commercial = false
	gw.release_build = false
	assert_int(gw.add_provider(_tts_cfg(server.url()))).is_equal(ERR_UNAUTHORIZED)
	assert_str(str(gw.state(TTS_ID))).is_equal("refused")
	assert_str(gw.reason(TTS_ID)).is_equal("non-commercial weights need the project setting npcf/providers/allow_non_commercial = true")
	ProviderFixture.idle(server, gw, 200)
	assert_int(server.requests.size()).is_equal(0)


func test_a_breeze_provider_declared_open_is_still_refused_without_allow() -> void:
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	gw.allow_non_commercial = false
	gw.release_build = false
	assert_int(gw.add_provider(_tts_cfg(server.url(), NpcfProviderConfig.License.OPEN))).is_equal(ERR_UNAUTHORIZED)
	assert_str(str(gw.state(TTS_ID))).is_equal("refused")


func test_with_allow_a_breeze_provider_becomes_ready() -> void:
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	gw.allow_non_commercial = true
	gw.release_build = false
	assert_int(gw.add_provider(_tts_cfg(server.url()))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, gw, func() -> bool: return gw.is_ready(TTS_ID))).is_true()


func test_a_release_build_refuses_a_breeze_provider_even_when_allowed() -> void:
	var server: FakeHttpServer = _server()
	var gw: NpcfProviderGateway = _gw()
	gw.allow_non_commercial = true
	gw.release_build = true
	assert_int(gw.add_provider(_tts_cfg(server.url()))).is_equal(ERR_UNAUTHORIZED)
	assert_str(gw.reason(TTS_ID)).is_equal("non-commercial weights are refused in release builds")
	ProviderFixture.idle(server, gw, 100)
	assert_int(server.requests.size()).is_equal(0)


func test_the_runtime_refuses_speech_without_the_project_setting() -> void:
	var server: FakeHttpServer = _server()
	ProjectSettings.set_setting(ALLOW_SETTING, false)
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_tts_cfg(server.url())]))).is_equal(OK)
	assert_str(str(rt.providers().state(TTS_ID))).is_equal("refused")
	var done: Array[StringName] = []
	rt.speak("hello", "", "", _discard(), _status_into(done))
	assert_str(str(done[0])).is_equal("off")
	ProviderFixture.idle(server, rt.providers(), 100)
	assert_int(server.requests.size()).is_equal(0)


func test_the_runtime_speaks_when_the_project_setting_allows_it() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = FakeHttpServer.Route.new()
	route.body = PackedByteArray([1, 2])
	server.routes[SPEECH] = route
	ProjectSettings.set_setting(ALLOW_SETTING, true)
	var rt: NpcfRuntime = _started()
	assert_int(rt.use_providers(_set_with([_tts_cfg(server.url())]))).is_equal(OK)
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return rt.providers().is_ready(TTS_ID))).is_true()
	var outputs: Array[PackedByteArray] = []
	var done: Array[StringName] = []
	rt.speak("hello", "", "", _collect(outputs), _status_into(done))
	assert_bool(ProviderFixture.pump(server, rt.providers(), func() -> bool: return done.size() == 1)).is_true()
	assert_bool(_joined(outputs) == PackedByteArray([1, 2])).is_true()
	assert_str(str(done[0])).is_equal("ok")
