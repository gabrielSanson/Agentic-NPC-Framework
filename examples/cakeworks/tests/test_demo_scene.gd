extends GdUnitTestSuite
## The playable demo scene in headless form (models off, as --no-models): seven NPC bodies with voice players, one
## player body, the HUD, room reports from the player's position, a typed line to Mira with her subtitle, and the
## three provider profiles. The profiles are read, never used, so no test reaches a server.

const DEMO_SCENE: String = "res://demo/demo_main.tscn"
const PROFILE_DIR: String = "res://demo/profiles/"
const MAX_FRAMES: int = 200
const PLAYER: StringName = &"cw.player"


func after_test() -> void:
	var rt: NpcfRuntime = get_node("/root/Npcf") as NpcfRuntime
	rt.stop()


func test_scene_has_seven_npcs_with_voices_one_player_and_a_hud() -> void:
	var demo: CwDemoMain = _start_demo()
	await _frames(2)
	var rt: NpcfRuntime = _runtime()
	assert_bool(rt.is_running()).is_true()
	var bodies: Array[Node] = demo.get_tree().get_nodes_in_group(&"cw_npc")
	assert_int(bodies.size()).is_equal(7)
	for body: Node in bodies:
		var voice: NpcfVoicePlayer2D = _voice_of(body)
		assert_object(voice).is_not_null()
		assert_bool(rt.get_world().npc_ids.has(voice.npc_id)).override_failure_message("%s has no NPC id" % body.name).is_true()
	assert_int(demo.get_tree().get_nodes_in_group(&"npcf_player").size()).is_equal(1)
	assert_object(_hud_of(demo)).is_not_null()


func test_player_room_is_reported_to_the_runtime() -> void:
	var demo: CwDemoMain = _start_demo()
	await _frames(2)
	var rt: NpcfRuntime = _runtime()
	var player: CwPlayer = _player_of(demo)
	player.position = rt.anchor_position(&"cw.production")
	await _frames_until(func() -> bool: return rt.location_of(PLAYER) == &"cw.production")
	assert_str(String(rt.location_of(PLAYER))).is_equal("cw.production")


func test_typed_line_to_mira_gets_a_subtitle_and_no_voice() -> void:
	var demo: CwDemoMain = _start_demo()
	# The runtime starts inside add_child, so the clock would tick during the first frames. Pause before any frame:
	# the start state is then the same on every machine.
	var rt: NpcfRuntime = _runtime()
	rt.pause()
	await _frames(2)
	var hud: CwHud = _hud_of(demo)
	var player: CwPlayer = _player_of(demo)
	var mira_body: CharacterBody2D = _body_named(demo, &"cw.mira")
	assert_object(mira_body).is_not_null()
	# Deterministic placement: stop the clock before anything moves. Mira's room is read while paused, so it cannot
	# change; the player is placed at that room's anchor. A paused clock applies no queued arrivals, so the arrival is
	# queued directly (the call the demo makes on a room change) and one tick is stepped by hand to apply it. No frames
	# run during the step, so frame timing cannot change the result.
	rt.pause()
	var mira_room: StringName = rt.location_of(&"cw.mira")
	player.position = rt.anchor_position(mira_room)
	var queued: Error = rt.report_player_location(mira_room)
	assert_int(queued).override_failure_message("arrival not queued: %s" % str(queued)).is_equal(OK)
	rt.resume()
	rt.advance_frame(rt.get_world().sim.real_seconds_per_tick / rt.speed)
	rt.pause()
	assert_str(String(rt.location_of(PLAYER))).override_failure_message("player not in Mira's room").is_equal(String(mira_room))
	# Stand just left of Mira and face her.
	player.facing_dir = Vector2.RIGHT
	player.position = mira_body.position + Vector2(-30, 0)
	# Area overlaps (the NPCs' hearing areas) refresh on physics frames, so wait for five before the submit. Still paused.
	await _physics_frames(5)
	var spoken: Array[String] = []
	rt.npc_line.connect(func(npc: StringName, text: String, _id: int, _src: StringName, _pres: Dictionary) -> void:
		spoken.append("%s|%s" % [str(npc), text]))
	var refusals: Array[String] = []
	rt.no_addressee.connect(func(reason: StringName) -> void: refusals.append(str(reason)))
	var voice: NpcfVoicePlayer2D = _voice_of(mira_body)
	var statuses: Array[String] = []
	voice.speech_finished.connect(func(_line: int, status: StringName) -> void: statuses.append(str(status)))
	var line_id: int = hud.submit("hello")
	assert_int(line_id).override_failure_message("no addressee: %s" % str(refusals)).is_greater_equal(0)
	# The addressee is fixed by the submit; the answer is produced on the ticks, so the clock runs again.
	rt.resume()
	await _frames_until(func() -> bool: return not spoken.is_empty() and not statuses.is_empty(), 600)
	assert_array(spoken).override_failure_message("no line from Mira").is_not_empty()
	assert_array(statuses).override_failure_message("no speech status from Mira's voice").is_not_empty()
	if not spoken.is_empty():
		assert_str(spoken[0].get_slice("|", 0)).is_equal("cw.mira")
	assert_str(hud.subtitle_text()).starts_with("Mira:")
	if not statuses.is_empty():
		assert_str(statuses[0]).is_equal("off")


func test_empty_submit_sends_nothing() -> void:
	var demo: CwDemoMain = _start_demo()
	await _frames(2)
	assert_int(_hud_of(demo).submit("   ")).is_equal(-1)


func test_profiles_list_the_expected_providers_and_ports() -> void:
	var light: NpcfProviderSet = _profile("light")
	assert_array(_ids(light)).is_equal([&"gemma", &"kev", &"parakeet", &"breeze"])
	assert_array(_timeouts(light)).is_equal([12000, 3000, 15000, 20000])
	assert_array(_ports(light)).is_equal([8090, 8009, 8010, 8080])
	assert_int(_config(light, &"breeze").license_use).is_equal(NpcfProviderConfig.License.NON_COMMERCIAL)
	assert_str(_config(light, &"kev").key_env).is_equal("KEV_API_KEY")
	var full: NpcfProviderSet = _profile("full")
	assert_array(_ids(full)).is_equal([&"gemma", &"kev", &"parakeet", &"breeze"])
	assert_array(_timeouts(full)).is_equal([8000, 2000, 10000, 10000])
	var text_only: NpcfProviderSet = _profile("text_only")
	assert_array(_ids(text_only)).is_equal([&"gemma", &"kev"])
	assert_array(_timeouts(text_only)).is_equal([12000, 3000])


# --- helpers -------------------------------------------------------------------------------------------------

## The demo with models off (the --no-models path), added to the tree and freed at the end of the test.
func _start_demo() -> CwDemoMain:
	var scene: PackedScene = load(DEMO_SCENE) as PackedScene
	var demo: CwDemoMain = scene.instantiate() as CwDemoMain
	demo.use_models = false
	demo.sim_speed = 16.0
	add_child(demo)
	return auto_free(demo)


func _runtime() -> NpcfRuntime:
	return get_node("/root/Npcf") as NpcfRuntime


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().process_frame


func _physics_frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


## Waits until the condition holds, at most `max_frames` frames. Returns when it holds or the budget ends.
func _frames_until(condition: Callable, max_frames: int = MAX_FRAMES) -> void:
	for _i: int in max_frames:
		var done: bool = condition.call()
		if done:
			return
		await get_tree().process_frame


func _body_named(demo: CwDemoMain, id: StringName) -> CharacterBody2D:
	for node: Node in demo.get_tree().get_nodes_in_group(&"cw_npc"):
		var body: CharacterBody2D = node as CharacterBody2D
		if body != null and _voice_of(body).npc_id == id:
			return body
	return null


func _voice_of(body: Node) -> NpcfVoicePlayer2D:
	for child: Node in body.get_children():
		if child is NpcfVoicePlayer2D:
			var voice: NpcfVoicePlayer2D = child as NpcfVoicePlayer2D
			return voice
	return null


func _player_of(demo: CwDemoMain) -> CwPlayer:
	for child: Node in demo.get_children():
		if child is CwPlayer:
			var player: CwPlayer = child as CwPlayer
			return player
	return null


func _hud_of(demo: CwDemoMain) -> CwHud:
	for child: Node in demo.get_children():
		if child is CwHud:
			var hud: CwHud = child as CwHud
			return hud
	return null


func _profile(name: String) -> NpcfProviderSet:
	var set_res: NpcfProviderSet = ResourceLoader.load(PROFILE_DIR + name + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfProviderSet
	assert_object(set_res).override_failure_message("cannot load profile %s" % name).is_not_null()
	return set_res


func _config(providers_set: NpcfProviderSet, id: StringName) -> NpcfProviderConfig:
	for cfg: NpcfProviderConfig in providers_set.providers:
		if cfg.id == id:
			return cfg
	return null


func _ids(providers_set: NpcfProviderSet) -> Array[StringName]:
	var out: Array[StringName] = []
	for cfg: NpcfProviderConfig in providers_set.providers:
		out.append(cfg.id)
	return out


func _timeouts(providers_set: NpcfProviderSet) -> Array[int]:
	var out: Array[int] = []
	for cfg: NpcfProviderConfig in providers_set.providers:
		out.append(cfg.timeout_ms)
	return out


func _ports(providers_set: NpcfProviderSet) -> Array[int]:
	var out: Array[int] = []
	for cfg: NpcfProviderConfig in providers_set.providers:
		out.append(cfg.base_url.get_slice(":", 2).to_int())
	return out
