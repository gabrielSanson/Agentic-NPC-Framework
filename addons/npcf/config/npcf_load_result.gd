class_name NpcfLoadResult
extends RefCounted
## The outcome of loading a pack: the loaded pack when `ok`, else every error found.

var ok: bool = false
var pack: NpcfLoadedPack = null
var errors: Array[NpcfConfigError] = []


## Every error formatted, one per line.
func format_errors() -> String:
	var lines: PackedStringArray = []
	for e: NpcfConfigError in errors:
		lines.append(e.format())
	return "\n".join(lines)
