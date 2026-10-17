class_name NpcfBreezeSpeechAdapter
extends NpcfProviderAdapter
## The Breeze-TTS-2.cpp server (breeze-server) for SPEAK: POST /v1/audio/speech as multipart. The reply streams raw
## mono s16le PCM at SAMPLE_RATE (a WAV header is stripped if the server sends one). Health is the default (GET /).
## Weights are non-commercial whatever the config says: the gateway gates every breeze_speech provider.

const SAMPLE_RATE: int = 24000
const WAV_HEADER_BYTES: int = 44


## Cuts the incoming bytes into whole samples. The first bytes decide whether a RIFF header comes first; if it does,
## its 44 bytes are dropped (they may arrive over several pieces). An odd last byte waits for the next piece. A reply
## shorter than the RIFF tag is passed on as soon as it cannot be a header.
class Stream extends RefCounted:
	var _carry: PackedByteArray = PackedByteArray()
	var _probing: bool = true
	var _skip_header: int = 0


	func feed(piece: PackedByteArray) -> PackedByteArray:
		var data: PackedByteArray = PackedByteArray()
		data.append_array(_carry)
		data.append_array(piece)
		_carry = PackedByteArray()
		if _probing:
			var tag: PackedByteArray = "RIFF".to_ascii_buffer()
			if data.size() < 4 and data == tag.slice(0, data.size()):
				_carry = data
				return PackedByteArray()
			_probing = false
			if data.size() >= 4 and data.slice(0, 4) == tag:
				_skip_header = WAV_HEADER_BYTES
		if _skip_header > 0:
			var drop: int = mini(_skip_header, data.size())
			_skip_header -= drop
			data = data.slice(drop)
		if data.size() % 2 == 1:
			_carry = data.slice(data.size() - 1)
			data = data.slice(0, data.size() - 1)
		return data


func kind() -> NpcfProviderConfig.Kind:
	return NpcfProviderConfig.Kind.SPEAK


## The text field, then instruction and voice_id when they are not empty. The timeout covers the whole stream, so a
## long line needs a larger timeout_ms in its config.
func build(cfg: NpcfProviderConfig, text: String, instruction: String, voice_id: String, boundary: String) -> NpcfHttpSpec:
	var body: PackedByteArray = NpcfMultipart.field(boundary, "text", text)
	if instruction != "":
		body.append_array(NpcfMultipart.field(boundary, "instruction", instruction))
	if voice_id != "":
		body.append_array(NpcfMultipart.field(boundary, "voice_id", voice_id))
	body.append_array(NpcfMultipart.finish(boundary))
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = HTTPClient.METHOD_POST
	s.path = "/v1/audio/speech"
	s.headers = PackedStringArray(["Content-Type: " + NpcfMultipart.content_type(boundary)])
	s.body = body
	s.timeout_ms = cfg.effective_timeout_ms()
	return s
