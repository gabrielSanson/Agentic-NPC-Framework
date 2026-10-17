class_name NpcfSaveService
extends RefCounted
## Atomic save files with one backup (R15.1). Paths: <dir>/<slot>.json, .json.tmp, .json.bak.

var dir: String = "user://saves"
## Test hook: stop after this step of write() to simulate a crash (-1 = never; the crash returns ERR_UNAVAILABLE). Steps: 1 tmp written,
## 2 old backup deleted, 3 save renamed to backup, 4 tmp renamed to save.
var stop_after_step: int = -1


## A slot is 1 to 64 characters of letters, digits, underscore and dash.
static func valid_slot(slot: String) -> bool:
	if slot.length() < 1 or slot.length() > 64:
		return false
	for i: int in slot.length():
		var c: int = slot.unicode_at(i)
		var digit: bool = c >= 48 and c <= 57
		var upper: bool = c >= 65 and c <= 90
		var lower: bool = c >= 97 and c <= 122
		if not (digit or upper or lower or c == 95 or c == 45):
			return false
	return true


func path_of(slot: String) -> String:
	return dir.path_join(slot + ".json")


## Writes the save text through a temp file, keeping the previous save as the backup.
func write(slot: String, text: String) -> Error:
	if not valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var made: Error = DirAccess.make_dir_recursive_absolute(dir)
	if made != OK:
		return made
	var main_path: String = path_of(slot)
	var tmp_path: String = main_path + ".tmp"
	var bak_path: String = main_path + ".bak"
	var written: Error = _write_tmp(tmp_path, text)
	if written != OK:
		return written
	if stop_after_step == 1:
		return ERR_UNAVAILABLE
	if FileAccess.file_exists(bak_path):
		var removed: Error = DirAccess.remove_absolute(bak_path)
		if removed != OK:
			return removed
	if stop_after_step == 2:
		return ERR_UNAVAILABLE
	if FileAccess.file_exists(main_path):
		var moved: Error = DirAccess.rename_absolute(main_path, bak_path)
		if moved != OK:
			return moved
	if stop_after_step == 3:
		return ERR_UNAVAILABLE
	return DirAccess.rename_absolute(tmp_path, main_path)


## [Error, text] for the main save or its backup. [ERR_FILE_CORRUPT, reason] when the file is missing or
## is not a JSON object.
func read(slot: String, use_backup: bool) -> Array:
	if not valid_slot(slot):
		return [ERR_INVALID_PARAMETER, "invalid save slot \"%s\"" % slot]
	var main_path: String = path_of(slot)
	var path: String = main_path + ".bak" if use_backup else main_path
	var text: String = ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if typeof(JSON.parse_string(text)) == TYPE_DICTIONARY:
		return [OK, text]
	var reason: String = "save file %s is missing or is not a valid save" % path
	if not use_backup and FileAccess.file_exists(main_path + ".bak"):
		reason += " (a backup exists: load it with use_backup = true)"
	return [ERR_FILE_CORRUPT, reason]


## Writes the temp file and checks that it reads back as a JSON object. Removes it otherwise.
func _write_tmp(tmp_path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	if typeof(JSON.parse_string(FileAccess.get_file_as_string(tmp_path))) != TYPE_DICTIONARY:
		DirAccess.remove_absolute(tmp_path)
		return ERR_FILE_CORRUPT
	return OK
