extends SceneTree
## Strict type check (R3.1, R3.2). Re-parses every GDScript file in the project except the
## vendored gdUnit4, with the project's warnings-as-errors settings and with
## `exclude_addons` switched off so that addons/npcf is checked too.
## `godot --headless --import` exits 0 even when scripts fail to parse, so CI uses this instead.
##
## Test suites extend gdUnit4 classes, which are not strictly typed, so they are checked in a
## second run with `-- --tests`, which keeps `exclude_addons` on (the suites themselves are still
## checked strictly because they live outside addons/).
##
## Usage: godot --headless --path . -s res://tools/ci/check_types.gd [-- --tests] [--root res://dir]


class ParseErrorLog extends Logger:
	var messages: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			messages.append("%s:%d: type: %s" % [file, line, rationale if rationale != "" else code])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _init() -> void:
	var root: String = "res://"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--root")
	if i >= 0 and i + 1 < args.size():
		root = args[i + 1]
	var tests_pass: bool = args.has("--tests")
	if tests_pass:
		root = "res://tests"
	else:
		ProjectSettings.set_setting("debug/gdscript/warnings/exclude_addons", false)
	var log: ParseErrorLog = ParseErrorLog.new()
	OS.add_logger(log)
	var failed: int = 0
	var files: PackedStringArray = CiUtil.files_under(root, PackedStringArray([".gd"]))
	var checked: int = 0
	for path: String in files:
		if ResourceLoader.has_cached(path):
			continue  # this checker and its helpers; they were compiled strictly to get here
		if not tests_pass and path.begins_with("res://tests/"):
			continue
		checked += 1
		var script: GDScript = GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		script.resource_path = path
		log.messages.clear()
		if script.reload() != OK:
			failed += 1
			for m: String in log.messages:
				printerr(m)
			if log.messages.is_empty():
				printerr("%s:0: type: script failed to parse" % path)
	OS.remove_logger(log)
	print("check_types%s: %d files, %d failing" % [" (tests)" if tests_pass else "", checked, failed])
	quit(1 if failed > 0 else 0)
