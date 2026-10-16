class_name CiUtil
extends RefCounted
## Shared helpers for the CI check scripts (file walking, comment and string stripping).

const SKIP_DIRS: PackedStringArray = [".godot", ".git", "reports"]


## Returns every file under `root` whose name ends with one of `exts`, sorted.
## Folders containing a `.gdignore` file and `res://addons/gdUnit4` are skipped.
static func files_under(root: String, exts: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	_walk(root, exts, out)
	out.sort()
	return out


static func _walk(dir_path: String, exts: PackedStringArray, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	if dir.file_exists(".gdignore") or dir_path == "res://addons/gdUnit4":
		return
	for f: String in dir.get_files():
		for ext: String in exts:
			if f.ends_with(ext):
				out.append(dir_path.path_join(f))
				break
	for sub: String in dir.get_directories():
		if SKIP_DIRS.has(sub):
			continue
		_walk(dir_path.path_join(sub), exts, out)


## Removes the comment part of a GDScript line (a `#` outside string literals).
static func strip_comment(line: String) -> String:
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if quote != "":
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
		i += 1
	return line


## Replaces the contents of string literals with spaces so code-only rules ignore them.
static func blank_strings(line: String) -> String:
	var out: String = ""
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if quote != "":
			if c == "\\":
				out += "  "
				i += 2
				continue
			if c == quote:
				quote = ""
				out += c
			else:
				out += " "
		else:
			if c == "\"" or c == "'":
				quote = c
			out += c
		i += 1
	return out


## Prints one violation in the `file:line: rule: detail` format and returns 1.
static func report(file: String, line: int, rule: String, detail: String) -> int:
	printerr("%s:%d: %s: %s" % [file, line, rule, detail])
	return 1
