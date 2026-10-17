extends GdUnitTestSuite
## The save files: atomic writes with one backup, the crash window between renames, slot checks and corrupt files.

const TEST_DIR: String = "user://npcf_test_saves/"


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(TEST_DIR + file_name)


func _service() -> NpcfSaveService:
	var svc: NpcfSaveService = NpcfSaveService.new()
	svc.dir = TEST_DIR
	return svc


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _listing() -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return PackedStringArray()
	var names: PackedStringArray = dir.get_files()
	names.sort()
	return names


func test_write_then_read() -> void:
	var svc: NpcfSaveService = _service()
	assert_int(svc.write("one", "{\"a\":1}")).is_equal(OK)
	var read: Array = svc.read("one", false)
	assert_int(read[0]).is_equal(OK)
	assert_str(read[1]).is_equal("{\"a\":1}")
	assert_bool(FileAccess.file_exists(svc.path_of("one") + ".tmp")).is_false()


func test_second_write_keeps_backup() -> void:
	var svc: NpcfSaveService = _service()
	assert_int(svc.write("two", "{\"v\":\"A\"}")).is_equal(OK)
	assert_int(svc.write("two", "{\"v\":\"B\"}")).is_equal(OK)
	assert_str(_text(svc.path_of("two"))).is_equal("{\"v\":\"B\"}")
	assert_str(_text(svc.path_of("two") + ".bak")).is_equal("{\"v\":\"A\"}")


func test_crash_between_renames() -> void:
	var svc: NpcfSaveService = _service()
	assert_int(svc.write("crash", "{\"v\":\"A\"}")).is_equal(OK)
	svc.stop_after_step = 3
	assert_int(svc.write("crash", "{\"v\":\"B\"}")).is_not_equal(OK)
	svc.stop_after_step = -1
	assert_bool(FileAccess.file_exists(svc.path_of("crash"))).is_false()
	assert_str(_text(svc.path_of("crash") + ".bak")).is_equal("{\"v\":\"A\"}")
	assert_str(_text(svc.path_of("crash") + ".tmp")).is_equal("{\"v\":\"B\"}")
	var main: Array = svc.read("crash", false)
	assert_int(main[0]).is_equal(ERR_FILE_CORRUPT)
	assert_str(main[1]).ends_with("(a backup exists: load it with use_backup = true)")
	var backup: Array = svc.read("crash", true)
	assert_int(backup[0]).is_equal(OK)
	assert_str(backup[1]).is_equal("{\"v\":\"A\"}")


func test_invalid_slot() -> void:
	var svc: NpcfSaveService = _service()
	assert_int(svc.write("one", "{}")).is_equal(OK)
	var before: PackedStringArray = _listing()
	assert_int(svc.write("../x", "{}")).is_equal(ERR_INVALID_PARAMETER)
	assert_array(Array(_listing())).is_equal(Array(before))
	var read: Array = svc.read("../x", false)
	assert_int(read[0]).is_equal(ERR_INVALID_PARAMETER)


func test_corrupt_main_file() -> void:
	var svc: NpcfSaveService = _service()
	assert_int(svc.write("bad", "{\"v\":\"A\"}")).is_equal(OK)
	assert_int(svc.write("bad", "{\"v\":\"B\"}")).is_equal(OK)
	var file: FileAccess = FileAccess.open(svc.path_of("bad"), FileAccess.WRITE)
	file.store_string("{")
	file.close()
	var read: Array = svc.read("bad", false)
	assert_int(read[0]).is_equal(ERR_FILE_CORRUPT)
	assert_str(read[1]).ends_with("(a backup exists: load it with use_backup = true)")
