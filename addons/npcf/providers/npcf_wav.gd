class_name NpcfWav
extends RefCounted
## Wraps raw 16-bit PCM in a standard 44-byte RIFF/WAVE header (PCM format 1), for upload to a transcription server.


## The header plus pcm. channels and sample_rate describe the pcm bytes; the header is written in little endian.
static func encode_pcm16(pcm: PackedByteArray, sample_rate: int, channels: int) -> PackedByteArray:
	var block_align: int = channels * 2
	var out: PackedByteArray = PackedByteArray()
	out.append_array(_ascii("RIFF"))
	out.append_array(_u32(36 + pcm.size()))
	out.append_array(_ascii("WAVE"))
	out.append_array(_ascii("fmt "))
	out.append_array(_u32(16))
	out.append_array(_u16(1))
	out.append_array(_u16(channels))
	out.append_array(_u32(sample_rate))
	out.append_array(_u32(sample_rate * block_align))
	out.append_array(_u16(block_align))
	out.append_array(_u16(16))
	out.append_array(_ascii("data"))
	out.append_array(_u32(pcm.size()))
	out.append_array(pcm)
	return out


static func _ascii(s: String) -> PackedByteArray:
	return s.to_ascii_buffer()


static func _u32(v: int) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


static func _u16(v: int) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(2)
	b.encode_u16(0, v)
	return b


## The data chunk of a RIFF/WAVE file that is PCM (format 1), mono, 16 bits and `rate` Hz. Otherwise empty. Chunks are
## walked by their size fields, so a LIST chunk before data is skipped; an odd chunk size has a pad byte.
static func read_pcm16_mono(bytes: PackedByteArray, rate: int) -> PackedByteArray:
	var none: PackedByteArray = PackedByteArray()
	if bytes.size() < 12 or _tag(bytes, 0) != "RIFF" or _tag(bytes, 8) != "WAVE":
		return none
	var pos: int = 12
	var fmt_ok: bool = false
	while pos + 8 <= bytes.size():
		var id: String = _tag(bytes, pos)
		var size: int = bytes.decode_u32(pos + 4)
		var body: int = pos + 8
		if body + size > bytes.size():
			return none
		if id == "fmt ":
			if size < 16:
				return none
			var format: int = bytes.decode_u16(body)
			var channels: int = bytes.decode_u16(body + 2)
			var sample_rate: int = bytes.decode_u32(body + 4)
			var bits: int = bytes.decode_u16(body + 14)
			if format != 1 or channels != 1 or sample_rate != rate or bits != 16:
				return none
			fmt_ok = true
		elif id == "data":
			return bytes.slice(body, body + size) if fmt_ok else none
		pos = body + size + (size % 2)
	return none


static func _tag(bytes: PackedByteArray, at: int) -> String:
	return bytes.slice(at, at + 4).get_string_from_ascii()
