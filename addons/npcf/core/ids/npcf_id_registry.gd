class_name NpcfIdRegistry
extends RefCounted
## Registry of every ID a pack defines, by kind (`fact`, `need`, `action`, ...). The same ID may
## exist under two kinds (a goal and an action can both be `toy.rest`), but not twice in one kind.

var _where: Dictionary[String, String] = {}
var _kinds_by_id: Dictionary[StringName, PackedStringArray] = {}


## Registers `id` under `kind`. Returns null when fine, or an error for a duplicate.
## `where` is the resource path that defines it.
func register(kind: StringName, id: StringName, where: String) -> NpcfConfigError:
	var key: String = _key(kind, id)
	if _where.has(key):
		return NpcfConfigError.make(where, "id", "duplicate %s ID \"%s\" (already defined in %s)" % [kind, id, _where[key]],
				"give each %s a unique ID" % kind)
	_where[key] = where
	var kinds: PackedStringArray = _kinds_by_id.get(id, PackedStringArray())
	kinds.append(String(kind))
	_kinds_by_id[id] = kinds
	return null


## Returns null when `id` is registered under `kind`; otherwise an error at `where`/`property`.
func require(kind: StringName, id: StringName, where: String, property: String = "") -> NpcfConfigError:
	if _where.has(_key(kind, id)):
		return null
	if _kinds_by_id.has(id):
		return NpcfConfigError.make(where, property, "\"%s\" is a %s, expected a %s" % [id, ", ".join(_kinds_by_id[id]), kind],
				"reference a %s here" % kind)
	return NpcfConfigError.make(where, property, "unknown %s \"%s\"" % [kind, id],
			"add it to the pack manifest or fix the ID")


## True when `id` is registered under `kind`.
func has(kind: StringName, id: StringName) -> bool:
	return _where.has(_key(kind, id))


## The resource path that defined `id` under `kind`, or an empty string.
func where_defined(kind: StringName, id: StringName) -> String:
	return _where.get(_key(kind, id), "")


func _key(kind: StringName, id: StringName) -> String:
	return "%s|%s" % [kind, id]
