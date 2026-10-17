class_name NpcfPcm
extends RefCounted
## Pure PCM helpers for the voice nodes. Stateless; every function is static.


## Averages the two channels of each frame.
static func to_mono(frames: PackedVector2Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	out.resize(frames.size())
	for i: int in frames.size():
		var f: Vector2 = frames[i]
		out[i] = (f.x + f.y) * 0.5
	return out


## Box-average resampler. Upsampling repeats samples (nearest neighbour).
static func resample(mono: PackedFloat32Array, from_rate: int, to_rate: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	if from_rate <= 0 or to_rate <= 0 or mono.is_empty():
		return out
	if from_rate == to_rate:
		var copy: PackedFloat32Array = mono.duplicate()
		return copy
	var r: float = float(from_rate) / float(to_rate)
	var out_len: int = floori(float(mono.size()) * float(to_rate) / float(from_rate))
	out.resize(out_len)
	for n: int in out_len:
		var i0: int = floori(n * r)
		var i1: int = maxi(i0 + 1, floori((n + 1) * r))
		i1 = mini(i1, mono.size())
		var total: float = 0.0
		for i: int in range(i0, i1):
			total += mono[i]
		out[n] = total / float(i1 - i0)
	return out


## Float samples in -1..1 to little-endian signed 16-bit PCM.
static func to_s16le(samples: PackedFloat32Array) -> PackedByteArray:
	var out: PackedByteArray = []
	out.resize(samples.size() * 2)
	for i: int in samples.size():
		var s: float = clampf(samples[i], -1.0, 1.0)
		var v: int = roundi(s * 32767.0)
		out.encode_s16(i * 2, v)
	return out


## Little-endian signed 16-bit PCM to stereo frames (the same value on both channels). A trailing odd byte is ignored.
static func s16le_to_frames(bytes: PackedByteArray) -> PackedVector2Array:
	var n: int = floori(bytes.size() * 0.5)
	var out: PackedVector2Array = []
	out.resize(n)
	for i: int in n:
		var v: float = bytes.decode_s16(i * 2) / 32768.0
		out[i] = Vector2(v, v)
	return out


## Duration of frame_count frames at rate per second. 0.0 when rate is not positive.
static func seconds(frame_count: int, rate: int) -> float:
	if rate <= 0:
		return 0.0
	return float(frame_count) / float(rate)
