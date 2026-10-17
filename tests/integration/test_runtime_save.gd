extends GdUnitTestSuite
## Runtime save and load: a loaded run continues like the unsaved one, refusals leave files and the running
## world untouched, invariant failures refuse a save, and autosave writes its slot. Toy basic, one tick per
## frame (each tick is 1.0 real seconds at speed 1).

const TEST_DIR: String = "user://npcf_test_saves/"
const SAVE_SEED: int = 5
const SAVE_TICK: int = 120
const AFTER_TICKS: int = 300

var _runtimes: Array[NpcfRuntime] = []


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(TEST_DIR + file_name)


## A started runtime in the test tree that saves into the test folder and is driven by the test.
func _started() -> NpcfRuntime:
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	rt.saves.dir = TEST_DIR
	_runtimes.append(rt)
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	manifest.sim.max_ticks_per_frame = 200
	assert_int(rt.start(manifest, ToyFixture.basic(), SAVE_SEED)).is_equal(OK)
	return rt


func _run(rt: NpcfRuntime, ticks: int) -> void:
	for _i: int in ticks:
		rt.advance_frame(1.0)


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The event log lines committed after `tick`, in the same format as NpcfEventQueue.log_text.
func _events_after(w: NpcfWorld, tick: int) -> String:
	var lines: PackedStringArray = []
	for e: NpcfEvent in w.events.log:
		if e.tick > tick:
			lines.append(JSON.stringify(e.to_dict(), "", true, true))
	return "\n".join(lines)


func test_save_load_round_trip() -> void:
	var rt: NpcfRuntime = _started()
	_run(rt, SAVE_TICK)
	assert_int(rt.save_game("round")).is_equal(OK)
	_run(rt, AFTER_TICKS)
	var expected: String = _events_after(rt.get_world(), SAVE_TICK)
	assert_bool(expected.is_empty()).is_false()
	var expected_state: String = NpcfSaveCodec.to_text(NpcfSaveCodec.encode(rt.get_world()))
	assert_int(rt.load_game("round")).is_equal(OK)
	assert_int(rt.get_world().clock.tick).is_equal(SAVE_TICK)
	_run(rt, AFTER_TICKS)
	assert_str(rt.get_world().events.log_text()).is_equal(expected)
	assert_str(NpcfSaveCodec.to_text(NpcfSaveCodec.encode(rt.get_world()))).is_equal(expected_state)


func test_same_seed_same_file() -> void:
	var first: NpcfRuntime = _started()
	var second: NpcfRuntime = _started()
	_run(first, SAVE_TICK)
	_run(second, SAVE_TICK)
	assert_int(first.save_game("first")).is_equal(OK)
	assert_int(second.save_game("second")).is_equal(OK)
	var first_bytes: PackedByteArray = FileAccess.get_file_as_bytes(first.saves.path_of("first"))
	var second_bytes: PackedByteArray = FileAccess.get_file_as_bytes(second.saves.path_of("second"))
	assert_bool(first_bytes.is_empty()).is_false()
	assert_bool(first_bytes == second_bytes).is_true()


func test_refusals_leave_files_untouched() -> void:
	var rt: NpcfRuntime = _started()
	_run(rt, SAVE_TICK)
	assert_int(rt.save_game("keep")).is_equal(OK)
	_run(rt, 10)
	assert_int(rt.save_game("keep")).is_equal(OK)
	var main_path: String = rt.saves.path_of("keep")
	var edited: Dictionary = NpcfSaveCodec.parse(_text(main_path))
	var pack_info: Dictionary = edited["pack"]
	pack_info["namespace"] = "zz"
	var file: FileAccess = FileAccess.open(main_path, FileAccess.WRITE)
	file.store_string(NpcfSaveCodec.to_text(edited))
	file.close()
	var main_before: String = _text(main_path)
	var backup_before: String = _text(main_path + ".bak")
	var world_before: NpcfWorld = rt.get_world()
	var tick_before: int = world_before.clock.tick
	var errors: Array[String] = []
	rt.sim_error.connect(func(message: String) -> void: errors.append(message))
	assert_int(rt.load_game("keep")).is_equal(ERR_FILE_CORRUPT)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("save is for pack")
	assert_str(_text(main_path)).is_equal(main_before)
	assert_str(_text(main_path + ".bak")).is_equal(backup_before)
	assert_object(rt.get_world()).is_same(world_before)
	assert_int(rt.get_world().clock.tick).is_equal(tick_before)


func test_invariant_failure_refuses_save() -> void:
	var rt: NpcfRuntime = _started()
	var always_fails: Callable = func(w: NpcfWorld) -> Array:
		var nobody: Array[StringName] = []
		return [NpcfInvariantFailure.make(&"test.always_fails", w.clock.tick, nobody, "always")]
	rt.get_world().invariants.extra.append(always_fails)
	assert_int(rt.save_game("refused")).is_equal(ERR_INVALID_DATA)
	assert_bool(FileAccess.file_exists(rt.saves.path_of("refused"))).is_false()


func test_autosave() -> void:
	var rt: NpcfRuntime = _started()
	rt.autosave_seconds = 1.0
	rt.advance_frame(0.55)
	rt.advance_frame(0.55)
	assert_bool(FileAccess.file_exists(rt.saves.path_of("autosave"))).is_true()
