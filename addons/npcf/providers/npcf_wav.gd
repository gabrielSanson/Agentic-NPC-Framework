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
