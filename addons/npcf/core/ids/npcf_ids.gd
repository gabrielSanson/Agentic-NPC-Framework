class_name NpcfIds
extends RefCounted
## ID rules (R3.4). Every ID is a StringName of the form `namespace.name`, lowercase.
## The framework's own IDs use the reserved `npcf` namespace.

const FRAMEWORK_NAMESPACE: StringName = &"npcf"
const GLOBAL_SUBJECT: StringName = &"npcf.global"
const PATTERN: String = "^[a-z][a-z0-9_]*\\.[a-z0-9_.]+$"
const NAMESPACE_PATTERN: String = "^[a-z][a-z0-9_]*$"

static var _id_re: RegEx = RegEx.create_from_string(PATTERN)
static var _ns_re: RegEx = RegEx.create_from_string(NAMESPACE_PATTERN)


## True when `id` matches the ID pattern.
static func is_valid(id: StringName) -> bool:
	return _id_re.search(String(id)) != null


## True when `ns` is a valid namespace (lowercase, no dot).
static func is_valid_namespace(ns: StringName) -> bool:
	return _ns_re.search(String(ns)) != null


## The namespace part of an ID (`toy` for `toy.rest`), or an empty StringName if there is none.
static func namespace_of(id: StringName) -> StringName:
	var s: String = String(id)
	var dot: int = s.find(".")
	if dot <= 0:
		return &""
	return StringName(s.substr(0, dot))


## Checks a pack ID: valid pattern, the pack's namespace, not the reserved `npcf` namespace.
## Returns an empty string when fine, otherwise the reason.
static func check_pack_id(id: StringName, pack_namespace: StringName) -> String:
	if String(id) == "":
		return "ID is empty"
	if not is_valid(id):
		return "\"%s\" does not match %s" % [id, PATTERN]
	var ns: StringName = namespace_of(id)
	if ns == FRAMEWORK_NAMESPACE:
		return "\"%s\" uses the reserved npcf namespace" % id
	if ns != pack_namespace:
		return "\"%s\" must start with the pack namespace \"%s.\"" % [id, pack_namespace]
	return ""
