extends SceneTree
## Mechanism/policy boundary check (R1.2, R2.5, R7.4, R13.9).
##
## Fails when:
## - a file under addons/npcf/ contains `res://packs/`, an ID-shaped string literal with a
##   namespace other than `npcf.`, or a word from tools/ci/denylist.txt;
## - a script under addons/npcf/core/ or addons/npcf/config/ references the scene tree;
## - `NpcfMemoryLog` is referenced from addons/npcf/ code outside the folders allowed to hold
##   memory (decision code must never read it);
## - decision, planning, needs, knowledge, social, director and memory code names a dialogue class (player text
##   must never reach decisions or state, R13);
## - any committed .tres or .tscn has a property named like api_key, token or secret with a
##   non-empty value.
##
## Usage: godot --headless --path . -s res://tools/ci/check_boundaries.gd [-- --root res://]


const ADDON: String = "addons/npcf/"
const SCENE_FREE_DIRS: PackedStringArray = ["addons/npcf/core/", "addons/npcf/config/"]
const MEMORY_ALLOWED_DIRS: PackedStringArray = [
	"addons/npcf/core/memory/", "addons/npcf/core/dialogue/", "addons/npcf/core/debug/",
	"addons/npcf/core/persistence/", "addons/npcf/core/world/", "addons/npcf/core/knowledge/",
]
## Code here must never name dialogue classes (intent, presentation, line generation, prompts, LLM transport).
const DIALOGUE_FORBIDDEN_DIRS: PackedStringArray = [
	"addons/npcf/core/decision/", "addons/npcf/core/planning/", "addons/npcf/core/needs/",
	"addons/npcf/core/knowledge/", "addons/npcf/core/social/", "addons/npcf/core/director/",
	"addons/npcf/core/memory/",
]
const FILE_EXTENSIONS: PackedStringArray = [
	"gd", "tres", "tscn", "json", "cfg", "txt", "md", "tmp", "bak", "res", "png", "svg", "sh",
]

var _failures: int = 0
var _id_literal: RegEx = RegEx.create_from_string("&?\"([a-z][a-z0-9_]*)\\.([a-z0-9_.]+)\"")
var _scene_ref: RegEx = RegEx.create_from_string(
		"\\b(Node|SceneTree|get_tree|get_main_loop|get_node|[A-Z][A-Za-z]*(?<!Transform)[23]D)\\b")
var _memory_ref: RegEx = RegEx.create_from_string("\\bNpcfMemoryLog\\b")
var _dialogue_ref: RegEx = RegEx.create_from_string(
		"\\bNpcf(Dialogue|Intent|LineGenerator|LineResult|LineValidator|Prompt|Llm|Presentation)[A-Za-z]*\\b")
var _secret_prop: RegEx = RegEx.create_from_string(
		"^\\s*([A-Za-z0-9_]*(api_key|token|secret)[A-Za-z0-9_]*)\\s*=\\s*\"([^\"]*)\"")
var _deny: Array[RegEx] = []
var _deny_words: PackedStringArray = []


func _init() -> void:
	var root: String = "res://"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--root")
	if i >= 0 and i + 1 < args.size():
		root = args[i + 1]
	_load_denylist()
	var addon_files: PackedStringArray = CiUtil.files_under(root.path_join(ADDON),
			PackedStringArray([".gd", ".tres", ".tscn", ".cfg"]))
	for path: String in addon_files:
		_check_addon_file(path, root)
	for path: String in CiUtil.files_under(root, PackedStringArray([".tres", ".tscn"])):
		_check_secrets(path)
	print("check_boundaries: %d addon files, %d violations" % [addon_files.size(), _failures])
	quit(1 if _failures > 0 else 0)


func _load_denylist() -> void:
	var text: String = FileAccess.get_file_as_string("res://tools/ci/denylist.txt")
	for raw: String in text.split("\n"):
		var w: String = raw.strip_edges().to_lower()
		if w == "" or w.begins_with("#"):
			continue
		_deny_words.append(w)
		_deny.append(RegEx.create_from_string("(?i)\\b" + w + "\\b"))


func _rel(path: String, root: String) -> String:
	return path.trim_prefix(root).trim_prefix("/")


func _check_addon_file(path: String, root: String) -> void:
	var rel: String = _rel(path, root)
	var is_script: bool = path.ends_with(".gd")
	var scene_free: bool = false
	for d: String in SCENE_FREE_DIRS:
		if rel.begins_with(d):
			scene_free = true
	var memory_allowed: bool = false
	for d: String in MEMORY_ALLOWED_DIRS:
		if rel.begins_with(d):
			memory_allowed = true
	var dialogue_forbidden: bool = false
	for d: String in DIALOGUE_FORBIDDEN_DIRS:
		if rel.begins_with(d):
			dialogue_forbidden = true
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for n: int in lines.size():
		var line: String = lines[n]
		var code: String = CiUtil.strip_comment(line) if is_script else line
		if line.contains("res://" + "packs/"):
			_failures += CiUtil.report(path, n + 1, "pack-path", "the addon must not name a pack path")
		for m: RegExMatch in _id_literal.search_all(code):
			var ns: String = m.get_string(1)
			var rest: String = m.get_string(2)
			if ns == "npcf" or FILE_EXTENSIONS.has(rest.get_extension() if rest.contains(".") else rest):
				continue
			_failures += CiUtil.report(path, n + 1, "namespace",
					"ID literal \"%s.%s\" uses a namespace other than npcf." % [ns, rest])
		for k: int in _deny.size():
			if _deny[k].search(line) != null:
				_failures += CiUtil.report(path, n + 1, "denylist",
						"word \"%s\" is on tools/ci/denylist.txt" % _deny_words[k])
		if not is_script:
			continue
		var bare: String = CiUtil.blank_strings(code)
		if scene_free:
			var sm: RegExMatch = _scene_ref.search(bare)
			if sm != null:
				_failures += CiUtil.report(path, n + 1, "scene-tree",
						"core/ and config/ must not reference %s" % sm.get_string(1))
		if not memory_allowed and _memory_ref.search(bare) != null:
			_failures += CiUtil.report(path, n + 1, "memory-boundary",
					"NpcfMemoryLog may only be referenced by memory, dialogue, debug, persistence, world and knowledge code")
		if dialogue_forbidden and _dialogue_ref.search(bare) != null:
			_failures += CiUtil.report(path, n + 1, "dialogue-boundary",
					"decision, planning, needs, knowledge, social, director and memory code must not reference dialogue classes")


func _check_secrets(path: String) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for n: int in lines.size():
		var m: RegExMatch = _secret_prop.search(lines[n])
		if m == null:
			continue
		var prop: String = m.get_string(1)
		if prop.ends_with("_env") or m.get_string(3) == "":
			continue
		_failures += CiUtil.report(path, n + 1, "secret",
				"property \"%s\" holds a value; API keys come only from environment variables" % prop)
