extends SceneTree
## Strict type check (R3.1, R3.2). Re-parses every GDScript file in the project except the
## vendored gdUnit4 with the project's warnings-as-errors settings (project.godot's
## directory_rules include addons/npcf). `godot --headless --import` exits 0 even when scripts
## fail to parse, so CI uses this instead.
##
## Usage: godot --headless --path . -s res://tools/ci/check_types.gd [-- --root res://dir]


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
	var log: ParseErrorLog = ParseErrorLog.new()
	OS.add_logger(log)
	var failed: int = 0
	var files: PackedStringArray = CiUtil.files_under(root, PackedStringArray([".gd"]))
	var checked: int = 0
	for path: String in files:
		if ResourceLoader.has_cached(path):
			continue  # this checker and its helpers; they were compiled strictly to get here
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
	print("check_types: %d files, %d failing" % [checked, failed])
	quit(1 if failed > 0 else 0)
