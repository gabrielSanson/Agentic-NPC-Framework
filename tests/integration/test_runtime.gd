extends GdUnitTestSuite
## The runtime driven headless: pacing (speed, pause, per-frame cap that never drops time), inputs applied in
## arrival order, bad events, signals, start and stop errors, player location and agent registration. Frames
## are driven with advance_frame; each tick of the toy pack is 1.0 real seconds at speed 1.

var _runtimes: Array[NpcfRuntime] = []


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()


## A runtime in the test tree with its frames driven by the test.
func _runtime() -> NpcfRuntime:
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	_runtimes.append(rt)
	return rt


## A fresh copy of the toy manifest, so a test may change its sim settings.
func _manifest() -> NpcfPackManifest:
	return ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest


## A running runtime on the toy pack and the basic scenario.
func _started(max_ticks: int = 2) -> NpcfRuntime:
	var rt: NpcfRuntime = _runtime()
	var manifest: NpcfPackManifest = _manifest()
	manifest.sim.max_ticks_per_frame = max_ticks
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	return rt


func _no_payload() -> Dictionary[StringName, Variant]:
	return {}


# --- pacing -------------------------------------------------------------------------------------

func test_ten_half_second_frames_make_five_ticks() -> void:
	var rt: NpcfRuntime = _started()
	var stepped: int = 0
	for _i: int in 10:
		stepped += rt.advance_frame(0.5)
	assert_int(stepped).is_equal(5)
	assert_int(rt.get_world().clock.tick).is_equal(5)
	assert_int(rt.frames).is_equal(10)


func test_pause_stops_time_and_resume_loses_no_ticks() -> void:
	var rt: NpcfRuntime = _started()
	rt.pause()
	var paused_steps: int = 0
	for _i: int in 10:
		paused_steps += rt.advance_frame(1.0)
	assert_int(paused_steps).is_equal(0)
	assert_int(rt.get_world().clock.tick).is_equal(0)
	rt.resume()
	var resumed_steps: int = 0
	for _i: int in 3:
		resumed_steps += rt.advance_frame(1.0)
	assert_int(resumed_steps).is_equal(3)
	assert_int(rt.get_world().clock.tick).is_equal(3)


func test_speed_scales_time_and_is_range_checked() -> void:
	var rt: NpcfRuntime = _started()
	assert_int(rt.set_speed(4.0)).is_equal(OK)
	assert_int(rt.advance_frame(0.25)).is_equal(1)
	assert_int(rt.set_speed(0.1)).is_equal(ERR_PARAMETER_RANGE_ERROR)
	assert_int(rt.set_speed(17.0)).is_equal(ERR_PARAMETER_RANGE_ERROR)
	assert_float(rt.speed).is_equal(4.0)


func test_cap_limits_ticks_per_frame_and_keeps_the_owed_time() -> void:
	var rt: NpcfRuntime = _started(2)
	assert_int(rt.advance_frame(10.0)).is_equal(2)
	assert_int(rt.capped_frames).is_equal(1)
	var total: int = 2
	for _i: int in 4:
		total += rt.advance_frame(0.0)
	assert_int(total).is_equal(10)
	assert_int(rt.get_world().clock.tick).is_equal(10)


# --- inputs and reports -------------------------------------------------------------------------

func test_reported_events_are_applied_in_call_order() -> void:
	var rt: NpcfRuntime = _started()
	var none: Array[StringName] = []
	var ana: Array[StringName] = [&"toy.ana"]
	var bo: Array[StringName] = [&"toy.bo"]
	assert_int(rt.report_event(&"toy.chatted", ana, none, &"toy.yard", _no_payload())).is_equal(OK)
	assert_int(rt.report_event(&"toy.chatted", bo, none, &"toy.yard", _no_payload())).is_equal(OK)
	assert_int(rt.advance_frame(1.0)).is_equal(1)
	var chats: Array[NpcfEvent] = []
	for e: NpcfEvent in rt.get_world().events.log:
		if e.kind == &"toy.chatted":
			chats.append(e)
	assert_int(chats.size()).is_equal(2)
	assert_str(str(chats[0].actors[0])).is_equal("toy.ana")
	assert_str(str(chats[1].actors[0])).is_equal("toy.bo")


func test_a_bad_event_is_refused_with_one_sim_error() -> void:
	var rt: NpcfRuntime = _started()
	var errors: Array[String] = []
	rt.sim_error.connect(func(message: String) -> void: errors.append(message))
	var none: Array[StringName] = []
	var code: Error = rt.report_event(&"toy.unknown_kind", none, none, &"", _no_payload())
	assert_int(code).is_equal(ERR_INVALID_PARAMETER)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("toy.unknown_kind")


func test_reports_before_start_are_unconfigured() -> void:
	var rt: NpcfRuntime = _runtime()
	var none: Array[StringName] = []
	assert_int(rt.report_event(&"toy.chatted", none, none, &"", _no_payload())).is_equal(ERR_UNCONFIGURED)
	assert_int(rt.report_player_location(&"toy.yard")).is_equal(ERR_UNCONFIGURED)
	assert_int(rt.advance_frame(5.0)).is_equal(0)


func test_player_location_is_checked_and_applied() -> void:
	var rt: NpcfRuntime = _started()
	var world: NpcfWorld = rt.get_world()
	assert_int(rt.report_player_location(&"toy.nowhere")).is_equal(ERR_DOES_NOT_EXIST)
	assert_int(rt.report_player_location(&"toy.workshop")).is_equal(OK)
	rt.advance_frame(1.0)
	assert_str(str(world.location_of(&"toy.player"))).is_equal("toy.workshop")
	assert_int(rt.report_player_location(&"toy.yard")).is_equal(OK)
	rt.advance_frame(1.0)
	assert_str(str(world.location_of(&"toy.player"))).is_equal("toy.yard")


# --- signals ------------------------------------------------------------------------------------

func test_tick_and_action_signals_fire_over_a_toy_run() -> void:
	var rt: NpcfRuntime = _started()
	var ticks: Array[int] = []
	var started: Array[StringName] = []
	var finished: Array[StringName] = []
	rt.tick_advanced.connect(func(tick: int) -> void: ticks.append(tick))
	rt.action_started.connect(func(_npc: StringName, action: StringName, _call_id: int) -> void: started.append(action))
	rt.action_finished.connect(func(_npc: StringName, _action: StringName, _call_id: int, outcome: StringName) -> void:
		finished.append(outcome))
	for _i: int in 300:
		rt.advance_frame(1.0)
	assert_int(ticks.size()).is_equal(300)
	assert_int(ticks[299]).is_equal(300)
	assert_bool(started.size() > 0).is_true()
	assert_bool(finished.size() > 0).is_true()
	assert_bool(finished.size() <= started.size()).is_true()


# --- start and stop -----------------------------------------------------------------------------

func test_starting_twice_is_refused() -> void:
	var rt: NpcfRuntime = _started()
	assert_int(rt.start(_manifest(), ToyFixture.basic(), 7)).is_equal(ERR_ALREADY_IN_USE)


func test_a_broken_manifest_is_refused_with_one_sim_error() -> void:
	var rt: NpcfRuntime = _runtime()
	var errors: Array[String] = []
	rt.sim_error.connect(func(message: String) -> void: errors.append(message))
	var manifest: NpcfPackManifest = _manifest()
	manifest.pack_namespace = &"Bad Name"
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(ERR_INVALID_DATA)
	assert_int(errors.size()).is_equal(1)
	assert_bool(rt.is_running()).is_false()


func test_stop_releases_the_world_and_allows_a_new_start() -> void:
	var rt: NpcfRuntime = _started()
	rt.stop()
	assert_bool(rt.is_running()).is_false()
	assert_int(rt.advance_frame(1.0)).is_equal(0)
	assert_int(rt.start(_manifest(), ToyFixture.basic(), 7)).is_equal(OK)
	assert_bool(rt.is_running()).is_true()


func test_setters_are_refused_while_running() -> void:
	var rt: NpcfRuntime = _started()
	assert_int(rt.set_movement_adapter(NpcfMovementAdapter.new())).is_equal(ERR_ALREADY_IN_USE)
	assert_int(rt.set_perception_adapter(NpcfPerceptionAdapter.new())).is_equal(ERR_ALREADY_IN_USE)
	assert_int(rt.set_presentation_adapter(NpcfPresentationAdapter.new())).is_equal(ERR_ALREADY_IN_USE)


# --- NPC registration and trace -----------------------------------------------------------------

func test_an_agent_registered_before_start_embodies_its_npc() -> void:
	var rt: NpcfRuntime = _runtime()
	var agent: NpcfAgent2D = auto_free(NpcfAgent2D.new())
	agent.npc_id = &"toy.ana"
	assert_int(rt.register_npc_node(&"toy.ana", agent)).is_equal(OK)
	assert_int(rt.start(_manifest(), ToyFixture.basic(), 7)).is_equal(OK)
	rt.advance_frame(1.0)
	assert_bool(rt.get_world().adapters.movement.is_embodied(&"toy.ana")).is_true()
	rt.unregister_npc_node(&"toy.ana")
	rt.advance_frame(1.0)
	assert_bool(rt.get_world().adapters.movement.is_embodied(&"toy.ana")).is_false()


func test_registering_an_unknown_npc_while_running_is_refused() -> void:
	var rt: NpcfRuntime = _started()
	var agent: NpcfAgent2D = auto_free(NpcfAgent2D.new())
	assert_int(rt.register_npc_node(&"toy.nobody", agent)).is_equal(ERR_DOES_NOT_EXIST)


func test_trace_describes_an_npc_and_is_empty_for_others() -> void:
	var rt: NpcfRuntime = _started()
	rt.advance_frame(3.0)
	var t: Dictionary = rt.trace(&"toy.ana")
	assert_bool(t.has("goal") and t.has("running") and t.has("decisions")).is_true()
	assert_str(str(t["npc"])).is_equal("toy.ana")
	assert_bool(rt.trace(&"toy.nobody").is_empty()).is_true()


# --- dialogue -----------------------------------------------------------------------------------

func test_player_say_before_start_is_not_running() -> void:
	var rt: NpcfRuntime = _runtime()
	var reasons: Array[StringName] = []
	rt.no_addressee.connect(func(reason: StringName) -> void: reasons.append(reason))
	assert_int(rt.player_say("hello", &"toy.ana")).is_equal(-1)
	assert_array(reasons).contains_exactly([&"not_running"])


func test_player_say_addresses_whoever_is_in_range_once_the_player_is_placed() -> void:
	var rt: NpcfRuntime = _started()
	assert_int(rt.report_player_location(&"toy.home_a")).is_equal(OK)
	rt.advance_frame(1.0)
	var reasons: Array[StringName] = []
	rt.no_addressee.connect(func(reason: StringName) -> void: reasons.append(reason))
	assert_int(rt.player_say("hello hey")).is_equal(-1)
	assert_array(reasons).contains_exactly([&"ambiguous"])


func test_player_say_emits_npc_line_with_five_arguments_while_paused() -> void:
	var rt: NpcfRuntime = _started()
	rt.pause()
	var got: Array[Array] = []
	rt.npc_line.connect(func(npc: StringName, text: String, line_id: int, source: StringName, presentation: Dictionary) -> void:
		got.append([npc, text, line_id, source, presentation]))
	assert_int(rt.player_say("hello hey", &"toy.ana")).is_equal(1)
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0][0])).is_equal("toy.ana")
	assert_int(got[0][2]).is_equal(1)
	assert_str(str(got[0][3])).is_equal("authored")
	var pres: Dictionary = got[0][4]
	assert_bool(pres.has(&"toy.emotion")).is_true()
	assert_int(rt.dialogue_records().size()).is_equal(1)


func test_clearing_the_line_generator_keeps_the_authored_lines() -> void:
	var rt: NpcfRuntime = _started()
	rt.set_line_generator(null)
	var sources: Array[StringName] = []
	rt.npc_line.connect(func(_npc: StringName, _text: String, _line_id: int, source: StringName, _pres: Dictionary) -> void:
		sources.append(source))
	assert_int(rt.player_say("hello hey", &"toy.ana")).is_greater(0)
	assert_array(sources).contains_exactly([&"authored"])


# --- speech instruction and voice (C4a) ----------------------------------------------------------

func test_speech_instruction_follows_layers_and_delivery() -> void:
	var rt: NpcfRuntime = _started()
	var out: String = rt.speech_instruction(&"toy.ana", {&"toy.emotion": &"toy.annoyed"})
	assert_str(out).ends_with("Clipped and irritated.")
	assert_str(out).contains("Brisk, crisp")
	assert_str(rt.speech_instruction(&"toy.nobody", {})).is_equal("")
	assert_str(rt.speech_voice_id(&"toy.ana")).is_equal("")


func test_speech_calls_answer_empty_when_not_running() -> void:
	var rt: NpcfRuntime = _runtime()
	assert_str(rt.speech_instruction(&"toy.ana", {})).is_equal("")
	assert_str(rt.speech_voice_id(&"toy.ana")).is_equal("")
