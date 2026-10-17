class_name NpcfErrorProbe
extends Logger
## Counts script errors so the hook runner can tell that a hook call failed.
##
## Spike result (task 6, Godot 4.5.2 and 4.7.2, --headless): a runtime error inside a function called through
## Callable.callv does NOT make the call return null. The function is aborted and the caller gets
## the declared return type's default (0.0, false, 0, an empty array, or null for objects), and
## execution continues. Return-value checks alone therefore cannot see most hook failures. Godot 4.5
## added the Logger API, which reports every script error synchronously, so the runner compares
## this probe's counter before and after each hook call.

var script_errors: int = 0
var last_message: String = ""


func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_SCRIPT or error_type == ERROR_TYPE_ERROR:
		script_errors += 1
		last_message = "%s:%d: %s" % [file, line, rationale if rationale != "" else code]


func _log_message(_message: String, _error: bool) -> void:
	pass
