extends GdUnitTestSuite
## NpcfPcm: channel mix, resampling, 16-bit conversion and durations.


func test_to_mono_averages_channels() -> void:
	var frames: PackedVector2Array = [Vector2(0.2, 0.4), Vector2(-1.0, 1.0)]
	var mono: PackedFloat32Array = NpcfPcm.to_mono(frames)
	assert_int(mono.size()).is_equal(2)
	assert_bool(is_equal_approx(mono[0], 0.3)).is_true()
	assert_bool(is_equal_approx(mono[1], 0.0)).is_true()


func test_resample_box_averages_when_downsampling() -> void:
	var out: PackedFloat32Array = NpcfPcm.resample([0.3, 0.3, 0.3, 0.6, 0.6, 0.6], 48000, 16000)
	assert_int(out.size()).is_equal(2)
	assert_bool(is_equal_approx(out[0], 0.3)).is_true()
	assert_bool(is_equal_approx(out[1], 0.6)).is_true()


func test_resample_44100_to_16000_keeps_level_and_length() -> void:
	var src: PackedFloat32Array = []
	src.resize(44100)
	src.fill(0.25)
	var out: PackedFloat32Array = NpcfPcm.resample(src, 44100, 16000)
	assert_int(out.size()).is_equal(16000)
	var worst: float = 0.0
	for v: float in out:
		worst = maxf(worst, absf(v - 0.25))
	assert_bool(worst <= 0.000001).is_true()


func test_resample_same_rate_copies_and_bad_input_is_empty() -> void:
	var same: PackedFloat32Array = NpcfPcm.resample([1.0, 2.0, 3.0, 4.0], 16000, 16000)
	assert_int(same.size()).is_equal(4)
	assert_bool(is_equal_approx(same[2], 3.0)).is_true()
	assert_int(NpcfPcm.resample([], 48000, 16000).size()).is_equal(0)
	assert_int(NpcfPcm.resample([0.5, 0.5], 0, 16000).size()).is_equal(0)


func test_resample_upsampling_is_nearest_neighbour() -> void:
	var out: PackedFloat32Array = NpcfPcm.resample([0.0, 1.0], 8000, 16000)
	assert_int(out.size()).is_equal(4)
	assert_bool(is_equal_approx(out[0], 0.0)).is_true()
	assert_bool(is_equal_approx(out[1], 0.0)).is_true()
	assert_bool(is_equal_approx(out[2], 1.0)).is_true()
	assert_bool(is_equal_approx(out[3], 1.0)).is_true()


func test_to_s16le_encodes_clamped_samples() -> void:
	var bytes: PackedByteArray = NpcfPcm.to_s16le([0.0, 0.5, 1.0, -1.0, 2.0])
	assert_int(bytes.size()).is_equal(10)
	var expected: Array[int] = [0, 16384, 32767, -32767, 32767]
	for i: int in expected.size():
		assert_int(bytes.decode_s16(i * 2)).is_equal(expected[i])


func test_s16le_to_frames_decodes_and_ignores_trailing_byte() -> void:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(5)
	bytes.encode_s16(0, 16384)
	bytes.encode_s16(2, -32768)
	bytes[4] = 7
	var frames: PackedVector2Array = NpcfPcm.s16le_to_frames(bytes)
	assert_int(frames.size()).is_equal(2)
	assert_bool(is_equal_approx(frames[0].x, 0.5) and is_equal_approx(frames[0].y, 0.5)).is_true()
	assert_bool(is_equal_approx(frames[1].x, -1.0) and is_equal_approx(frames[1].y, -1.0)).is_true()


func test_s16le_round_trip_stays_within_one_step() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var samples: PackedFloat32Array = []
	for i: int in 100:
		samples.append(rng.randf_range(-1.0, 1.0))
	var frames: PackedVector2Array = NpcfPcm.s16le_to_frames(NpcfPcm.to_s16le(samples))
	assert_int(frames.size()).is_equal(100)
	var worst: float = 0.0
	for i: int in 100:
		worst = maxf(worst, absf(frames[i].x - samples[i]))
	# Encode scales by 32767 and decode divides by 32768, so the worst case is 0.5 step of rounding plus
	# 1/32768 of scale: about 1.5 steps. Two steps is the bound that holds.
	assert_bool(worst <= 2.0 / 32767.0).override_failure_message("worst error %f" % worst).is_true()


func test_seconds_from_frames_and_rate() -> void:
	assert_bool(is_equal_approx(NpcfPcm.seconds(24000, 48000), 0.5)).is_true()
	assert_bool(is_equal_approx(NpcfPcm.seconds(10, 0), 0.0)).is_true()
