extends GdUnitTestSuite
## NpcfVoicePlayer2D: npc_id from the sibling agent, subtitle before speech, streamed chunks, completion once,
## interruption by a newer line, the earshot rule, and the real speech call without providers.

class FakePlayer extends NpcfVoicePlayer2D:
	var requests: Array[Array] = []
	var on_chunks: Array[Callable] = []
	var on_dones: Array[Callable] = []
	func request_speech(text: String, instruction: String, voice_id: String, on_chunk: Callable, on_done: Callable) -> void:
		requests.append([text, instruction, voice_id])
		on_chunks.append(on_chunk)
		on_dones.append(on_done)


var _runtimes: Array[NpcfRuntime] = []


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()


## A Node2D in the test tree; children added to it are freed with it.
func _parent() -> Node2D:
	var parent: Node2D = auto_free(Node2D.new())
	get_tree().root.add_child(parent)
	return parent


## A runtime in the test tree, not started, with its frames driven by the test.
func _runtime(parent: Node2D) -> NpcfRuntime:
	var rt: NpcfRuntime = NpcfRuntime.new()
	rt.auto_process = false
	parent.add_child(rt)
	_runtimes.append(rt)
	return rt


func _player(parent: Node2D, rt: NpcfRuntime, npc: StringName = &"toy.ana") -> FakePlayer:
	var player: FakePlayer = FakePlayer.new()
	player.npc_id = npc
	player.runtime_path = rt.get_path()
	parent.add_child(player)
	return player


## count samples of value as s16le bytes.
func _pcm(count: int, value: int) -> PackedByteArray:
	var out: PackedByteArray = []
	out.resize(count * 2)
	for i: int in count:
		out.encode_s16(i * 2, value)
	return out


func _drain(player: FakePlayer) -> void:
	for i: int in 50:
		if player.pending_frames() == 0:
			return
		player._process(0.016)
		await get_tree().process_frame


func test_npc_id_is_taken_from_an_agent_sibling_when_empty() -> void:
	var parent: Node2D = _parent()
	var agent: NpcfAgent2D = NpcfAgent2D.new()
	agent.npc_id = &"toy.ana"
	parent.add_child(agent)
	var player: NpcfVoicePlayer2D = NpcfVoicePlayer2D.new()
	parent.add_child(player)
	assert_str(str(player.npc_id)).is_equal("toy.ana")


func test_subtitle_comes_before_one_speech_request_and_other_npcs_are_ignored() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = _runtime(parent)
	var player: FakePlayer = _player(parent, rt)
	var log: Array[String] = []
	player.subtitle.connect(func(_n: StringName, text: String, _id: int, _p: Dictionary) -> void: log.append("subtitle:" + text))
	rt.npc_line.emit(&"toy.ben", "Not for you.", 6, &"authored", {})
	rt.npc_line.emit(&"toy.ana", "Hi.", 7, &"authored", {})
	assert_array(log).is_equal(["subtitle:Hi."])
	assert_int(player.requests.size()).is_equal(1)
	assert_str(str(player.requests[0][0])).is_equal("Hi.")
	assert_int(player.current_line()).is_equal(7)


func test_chunks_start_playback_and_drain_into_the_generator() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = _runtime(parent)
	var player: FakePlayer = _player(parent, rt)
	var started: Array[int] = []
	player.speech_started.connect(func(id: int) -> void: started.append(id))
	rt.npc_line.emit(&"toy.ana", "Hi.", 7, &"authored", {})
	player.on_chunks[0].call(_pcm(2400, 8192))
	assert_array(started).is_equal([7])
	assert_bool(player.playing).is_true()
	player._process(0.016)
	assert_bool(player.pending_frames() < 2400).is_true()


func test_done_finishes_the_line_once_after_the_pending_frames() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = _runtime(parent)
	var player: FakePlayer = _player(parent, rt)
	var finished: Array[Array] = []
	player.speech_finished.connect(func(id: int, status: StringName) -> void: finished.append([id, status]))
	rt.npc_line.emit(&"toy.ana", "Hi.", 7, &"authored", {})
	player.on_chunks[0].call(_pcm(2400, 8192))
	player.on_dones[0].call(&"ok")
	await _drain(player)
	assert_int(player.pending_frames()).is_equal(0)
	player._process(0.016)
	assert_int(finished.size()).is_equal(1)
	assert_int(finished[0][0]).is_equal(7)
	assert_str(str(finished[0][1])).is_equal("ok")


func test_a_newer_line_interrupts_and_the_old_chunks_change_nothing() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = _runtime(parent)
	var player: FakePlayer = _player(parent, rt)
	var finished: Array[Array] = []
	var started: Array[int] = []
	player.speech_finished.connect(func(id: int, status: StringName) -> void: finished.append([id, status]))
	player.speech_started.connect(func(id: int) -> void: started.append(id))
	rt.npc_line.emit(&"toy.ana", "First.", 7, &"authored", {})
	rt.npc_line.emit(&"toy.ana", "Second.", 8, &"authored", {})
	assert_array(finished).is_equal([[7, &"interrupted"]])
	player.on_chunks[0].call(_pcm(2400, 8192))
	assert_int(player.pending_frames()).is_equal(0)
	assert_array(started).is_empty()
	assert_int(player.current_line()).is_equal(8)
	player.on_chunks[1].call(_pcm(2400, 8192))
	assert_array(started).is_equal([8])
	assert_int(finished.size()).is_equal(1)


func test_out_of_earshot_drops_the_audio_but_the_subtitle_still_goes_out() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = _runtime(parent)
	var far: Node2D = Node2D.new()
	far.position = Vector2(10000, 0)
	far.add_to_group(&"npcf_player")
	parent.add_child(far)
	var player: FakePlayer = _player(parent, rt)
	player.earshot_px = 600.0
	var subs: Array[String] = []
	var finished: Array[Array] = []
	player.subtitle.connect(func(_n: StringName, text: String, _id: int, _p: Dictionary) -> void: subs.append(text))
	player.speech_finished.connect(func(id: int, status: StringName) -> void: finished.append([id, status]))
	rt.npc_line.emit(&"toy.ana", "Hi.", 7, &"authored", {})
	player.on_chunks[0].call(_pcm(2400, 8192))
	assert_bool(player.playing).is_false()
	assert_int(player.pending_frames()).is_equal(0)
	player.on_dones[0].call(&"ok")
	assert_array(finished).is_equal([[7, &"out_of_earshot"]])
	assert_array(subs).is_equal(["Hi."])


func test_without_providers_the_line_gets_its_subtitle_then_speech_off() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = _runtime(parent)
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	var player: NpcfVoicePlayer2D = NpcfVoicePlayer2D.new()
	player.npc_id = &"toy.ana"
	player.runtime_path = rt.get_path()
	parent.add_child(player)
	var log: Array[String] = []
	player.subtitle.connect(func(_n: StringName, text: String, _id: int, _p: Dictionary) -> void: log.append("subtitle:" + text))
	player.speech_finished.connect(func(id: int, status: StringName) -> void: log.append("finished:%d:%s" % [id, status]))
	rt.npc_line.emit(&"toy.ana", "Hello.", 1, &"authored", {&"toy.emotion": &"toy.calm"})
	assert_array(log).is_equal(["subtitle:Hello.", "finished:1:off"])
	assert_bool(player.playing).is_false()


func test_earshot_zero_is_always_audible() -> void:
	var parent: Node2D = _parent()
	var rt: NpcfRuntime = _runtime(parent)
	var far: Node2D = Node2D.new()
	far.position = Vector2(10000, 0)
	far.add_to_group(&"npcf_player")
	parent.add_child(far)
	var player: FakePlayer = _player(parent, rt)
	player.earshot_px = 0.0
	rt.npc_line.emit(&"toy.ana", "Hi.", 7, &"authored", {})
	player.on_chunks[0].call(_pcm(2400, 8192))
	assert_bool(player.playing).is_true()
