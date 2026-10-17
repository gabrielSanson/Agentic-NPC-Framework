extends SceneTree
## Determinism lint (R18.4). Scans pack scripts (packs/**.gd) and the simulation core
## (addons/npcf/core/**.gd) and fails on global random functions, wall-clock time and scene-tree
## access. In pack scripts it also fails on access to underscore-prefixed members, which are
## private to the framework's read-only views.
##
## Usage: godot --headless --path . -s res://tools/ci/lint_hooks.gd [-- --root res://]


var _failures: int = 0
var _rules: Dictionary[String, RegEx] = {
	"global-random": RegEx.create_from_string("(?<![.\\w])(randf|randi|randf_range|randi_range|randfn|randomize|seed|rand_from_seed)\\s*\\("),
	"wall-clock": RegEx.create_from_string("\\b(Time\\.|OS\\.get_ticks|OS\\.get_unix_time|OS\\.get_system_time)"),
	"scene-tree": RegEx.create_from_string("\\b(get_tree|get_node|Engine\\.get_main_loop)\\b"),
}
var _private_access: RegEx = RegEx.create_from_string("\\.\\s*_[a-z]\\w*")


func _init() -> void:
	var root: String = "res://"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--root")
	if i >= 0 and i + 1 < args.size():
		root = args[i + 1]
	var pack_files: PackedStringArray = CiUtil.files_under(root.path_join("packs"), PackedStringArray([".gd"]))
	var core_files: PackedStringArray = CiUtil.files_under(root.path_join("addons/npcf/core"), PackedStringArray([".gd"]))
	for path: String in pack_files:
		_scan(path, true)
	for path: String in core_files:
		_scan(path, false)
	print("lint_hooks: %d files, %d violations" % [pack_files.size() + core_files.size(), _failures])
	quit(1 if _failures > 0 else 0)


func _scan(path: String, is_pack: bool) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for n: int in lines.size():
		var code: String = CiUtil.blank_strings(CiUtil.strip_comment(lines[n]))
		for rule: String in _rules:
			var m: RegExMatch = _rules[rule].search(code)
			if m != null:
				_failures += CiUtil.report(path, n + 1, rule, "\"%s\" breaks determinism" % m.get_string(1))
		if is_pack:
			var pm: RegExMatch = _private_access.search(code)
			if pm != null and not code.strip_edges().begins_with("func "):
				_failures += CiUtil.report(path, n + 1, "private-access",
						"\"%s\": hooks may only use the public getters of framework views" % pm.get_string().strip_edges())
