extends GdUnitTestSuite
## NpcfMicCapture: the capture bus and action it creates, the record, send and deliver path, the failure statuses,
## the length limits, the busy state, the real runtime without providers, and freeing before the answer.
## No audio device is used: the test feeds frames through feed().

class FakeMic extends NpcfMicCapture:
	var sent: Array[PackedByteArray] = []
	var callbacks: Array[Callable] = []
	var said: Array[String] = []
	var log: Array[String] = []
	func send_for_transcription(pcm: PackedByteArray, on_done: Callable) -> void:
		sent.append(pcm)
		callbacks.append(on_done)
	func deliver_transcript(text: String) -> void:
		said.append(text)
		log.append("deliver:" + text)


func after_test() -> void:
	var idx: int = AudioServer.get_bus_index(&"NpcfMic")
	if idx != -1:
		AudioServer.remove_bus(idx)
	if InputMap.has_action(&"npcf_push_to_talk"):
		InputMap.erase_action(&"npcf_push_to_talk")


## A Node2D in the test tree; children added to it are freed with it.
func _parent() -> Node2D:
	var parent: Node2D = auto_free(Node2D.new())
	get_tree().root.add_child(parent)
	return parent


func _mic(parent: Node2D, rate: int) -> FakeMic:
	var mic: FakeMic = FakeMic.new()
	mic.source_rate = rate
	parent.add_child(mic)
	return mic


func _frames(count: int, value: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	out.resize(count)
	out.fill(Vector2(value, value))
	return out


## Records count frames of value at rate, then stops (the release of the key).
func _record(mic: FakeMic, count: int, value: float) -> void:
	mic.start()
	mic.feed(_frames(count, value))
	mic.stop()


func test_ready_creates_a_muted_capture_bus_and_the_push_to_talk_action() -> void:
	_mic(_parent(), 16000)
	var idx: int = AudioServer.get_bus_index(&"NpcfMic")
	assert_int(idx).is_not_equal(-1)
	assert_bool(AudioServer.is_bus_mute(idx)).is_true()
	var has_capture: bool = false
	for k: int in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, k) is AudioEffectCapture:
			has_capture = true
	assert_bool(has_capture).is_true()
	assert_bool(InputMap.has_action(&"npcf_push_to_talk")).is_true()


func test_half_a_second_at_48k_is_sent_as_16k_pcm() -> void:
	var mic: FakeMic = _mic(_parent(), 48000)
	var secs: Array[float] = []
	mic.recording_stopped.connect(func(s: float) -> void: secs.append(s))
	_record(mic, 24000, 0.5)
	assert_int(mic.sent.size()).is_equal(1)
	assert_int(mic.sent[0].size()).is_equal(16000)
	assert_int(mic.sent[0].decode_s16(0)).is_equal(16384)
	assert_int(secs.size()).is_equal(1)
	assert_bool(is_equal_approx(secs[0], 0.5)).is_true()


func test_transcript_is_emitted_before_it_is_delivered() -> void:
	var mic: FakeMic = _mic(_parent(), 16000)
	mic.transcript_ready.connect(func(t: String) -> void: mic.log.append("ready:" + t))
	_record(mic, 8000, 0.2)
	mic.callbacks[0].call("  hello there ", &"ok")
	assert_array(mic.log).is_equal(["ready:hello there", "deliver:hello there"])
	assert_array(mic.said).is_equal(["hello there"])


func test_a_recording_under_min_seconds_is_too_short_and_nothing_is_sent() -> void:
	var mic: FakeMic = _mic(_parent(), 16000)
	var failed: Array[StringName] = []
	mic.transcribe_failed.connect(func(s: StringName) -> void: failed.append(s))
	_record(mic, 1600, 0.2)
	assert_array(failed).is_equal([&"too_short"])
	assert_int(mic.sent.size()).is_equal(0)


func test_empty_text_and_failed_statuses_are_reported_and_not_said() -> void:
	var mic: FakeMic = _mic(_parent(), 16000)
	var failed: Array[StringName] = []
	mic.transcribe_failed.connect(func(s: StringName) -> void: failed.append(s))
	_record(mic, 8000, 0.2)
	mic.callbacks[0].call("", &"ok")
	_record(mic, 8000, 0.2)
	mic.callbacks[1].call("x", &"http")
	assert_array(failed).is_equal([&"empty", &"http"])
	assert_array(mic.said).is_empty()


func test_reaching_max_seconds_stops_the_recording_on_its_own() -> void:
	var mic: FakeMic = _mic(_parent(), 16000)
	mic.max_seconds = 1.0
	mic.start()
	mic.feed(_frames(20000, 0.2))
	assert_bool(mic.is_recording()).is_false()
	assert_int(mic.sent.size()).is_equal(1)


func test_while_busy_start_does_nothing() -> void:
	var mic: FakeMic = _mic(_parent(), 16000)
	_record(mic, 8000, 0.2)
	assert_bool(mic.is_busy()).is_true()
	mic.start()
	assert_bool(mic.is_recording()).is_false()
	mic.callbacks[0].call("done", &"ok")
	assert_bool(mic.is_busy()).is_false()


func test_without_providers_the_status_is_off_and_player_say_is_never_called() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = NpcfRuntime.new()
	rt.auto_process = false
	parent.add_child(rt)
	var mic: NpcfMicCapture = NpcfMicCapture.new()
	mic.source_rate = 16000
	mic.runtime_path = rt.get_path()
	parent.add_child(mic)
	var failed: Array[StringName] = []
	var refused: Array[StringName] = []
	mic.transcribe_failed.connect(func(s: StringName) -> void: failed.append(s))
	rt.no_addressee.connect(func(reason: StringName) -> void: refused.append(reason))
	mic.start()
	mic.feed(_frames(8000, 0.2))
	mic.stop()
	assert_array(failed).is_equal([&"off"])
	assert_array(refused).is_empty()


func test_freeing_the_node_before_the_answer_is_safe() -> void:
	var parent: Node2D = _parent()
	var mic: FakeMic = _mic(parent, 16000)
	var heard: Array[String] = []
	mic.transcript_ready.connect(func(t: String) -> void: heard.append(t))
	_record(mic, 8000, 0.2)
	var answer: Callable = mic.callbacks[0]
	mic.free()
	answer.call("hello", &"ok")
	assert_array(heard).is_empty()
