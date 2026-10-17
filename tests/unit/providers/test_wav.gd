extends GdUnitTestSuite
## C6c (section 4.2): NpcfWav.read_pcm16_mono gives back the data chunk only for 16 kHz mono 16-bit PCM.

const RATE: int = 16000


func _pcm() -> PackedByteArray:
	var pcm: PackedByteArray = PackedByteArray([1, 0, 2, 0, 3, 0, 4, 0])
	return pcm


func test_a_round_trip_gives_back_the_pcm() -> void:
	var wav: PackedByteArray = NpcfWav.encode_pcm16(_pcm(), RATE, 1)
	assert_bool(NpcfWav.read_pcm16_mono(wav, RATE) == _pcm()).is_true()


func test_a_stereo_header_gives_empty() -> void:
	var wav: PackedByteArray = NpcfWav.encode_pcm16(_pcm(), RATE, 2)
	assert_bool(NpcfWav.read_pcm16_mono(wav, RATE).is_empty()).is_true()


func test_a_24_kHz_header_gives_empty_for_16_kHz() -> void:
	var wav: PackedByteArray = NpcfWav.encode_pcm16(_pcm(), 24000, 1)
	assert_bool(NpcfWav.read_pcm16_mono(wav, RATE).is_empty()).is_true()


func test_an_8_bit_header_gives_empty() -> void:
	var wav: PackedByteArray = NpcfWav.encode_pcm16(_pcm(), RATE, 1)
	wav.encode_u16(34, 8)
	assert_bool(NpcfWav.read_pcm16_mono(wav, RATE).is_empty()).is_true()


func test_a_list_chunk_with_odd_size_before_data_still_works() -> void:
	var wav: PackedByteArray = NpcfWav.encode_pcm16(_pcm(), RATE, 1)
	var head: PackedByteArray = wav.slice(0, 36)
	var tail: PackedByteArray = wav.slice(36)
	var list: PackedByteArray = "LIST".to_ascii_buffer()
	var size: PackedByteArray = PackedByteArray([5, 0, 0, 0])
	list.append_array(size)
	list.append_array("abcde".to_ascii_buffer())
	list.append(0)
	var with_list: PackedByteArray = PackedByteArray()
	with_list.append_array(head)
	with_list.append_array(list)
	with_list.append_array(tail)
	assert_bool(NpcfWav.read_pcm16_mono(with_list, RATE) == _pcm()).is_true()


func test_truncated_input_gives_empty() -> void:
	var wav: PackedByteArray = NpcfWav.encode_pcm16(_pcm(), RATE, 1)
	assert_bool(NpcfWav.read_pcm16_mono(wav.slice(0, wav.size() - 2), RATE).is_empty()).is_true()
	assert_bool(NpcfWav.read_pcm16_mono(wav.slice(0, 20), RATE).is_empty()).is_true()
	assert_bool(NpcfWav.read_pcm16_mono(PackedByteArray(), RATE).is_empty()).is_true()
