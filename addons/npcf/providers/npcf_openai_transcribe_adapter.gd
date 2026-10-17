class_name NpcfOpenAiTranscribeAdapter
extends NpcfProviderAdapter
## The OpenAI-style transcription server (our Parakeet wrapper in the demo) for TRANSCRIBE: POST
## /v1/audio/transcriptions as multipart with the audio as 16 kHz mono WAV. Health is GET /health (cfg.extra
## health_path overrides it); any answer below 500 counts as up.

const SAMPLE_RATE: int = 16000


func kind() -> NpcfProviderConfig.Kind:
	return NpcfProviderConfig.Kind.TRANSCRIBE


func health_spec(cfg: NpcfProviderConfig) -> NpcfHttpSpec:
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = HTTPClient.METHOD_GET
	s.path = str(cfg.extra.get(&"health_path", "/health"))
	s.timeout_ms = cfg.health_timeout_ms
	return s


## pcm16_mono is raw 16-bit PCM at SAMPLE_RATE. The parts are: file, model (when set), response_format.
func build(cfg: NpcfProviderConfig, pcm16_mono: PackedByteArray, boundary: String) -> NpcfHttpSpec:
	var body: PackedByteArray = PackedByteArray()
	var wav: PackedByteArray = NpcfWav.encode_pcm16(pcm16_mono, SAMPLE_RATE, 1)
	body.append_array(NpcfMultipart.file(boundary, "file", "audio" + ".wav", "audio/wav", wav))
	if cfg.model != "":
		body.append_array(NpcfMultipart.field(boundary, "model", cfg.model))
	body.append_array(NpcfMultipart.field(boundary, "response_format", "json"))
	body.append_array(NpcfMultipart.finish(boundary))
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = HTTPClient.METHOD_POST
	s.path = "/v1/audio/transcriptions"
	s.headers = PackedStringArray(["Content-Type: " + NpcfMultipart.content_type(boundary)])
	s.body = body
	s.timeout_ms = cfg.effective_timeout_ms()
	return s


## The text field when the reply is ok and has one, else "". The caller checks the status.
func parse(r: NpcfHttpResult) -> String:
	if r.status != &"ok":
		return ""
	var data: Dictionary = r.json()
	var text: Variant = data.get("text")
	if text is String:
		var s: String = text
		return s
	return ""
