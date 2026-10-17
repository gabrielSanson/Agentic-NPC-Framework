class_name NpcfHookParams
extends RefCounted
## Read-only parameters handed to a consideration hook (copied from NpcfConsiderationDef.hook_params).

var _values: Dictionary[StringName, Variant] = {}


func _init(values: Dictionary[StringName, Variant] = {}) -> void:
	_values = values.duplicate()


func has(name: StringName) -> bool:
	return _values.has(name)


func get_value(name: StringName, default: Variant = null) -> Variant:
	return _values.get(name, default)


func get_float(name: StringName, default: float = 0.0) -> float:
	var v: Variant = _values.get(name, default)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		var f: float = v
		return f
	return default


func get_int(name: StringName, default: int = 0) -> int:
	var v: Variant = _values.get(name, default)
	if typeof(v) == TYPE_INT:
		var i: int = v
		return i
	return default


func get_name_value(name: StringName, default: StringName = &"") -> StringName:
	var v: Variant = _values.get(name, default)
	if typeof(v) == TYPE_STRING_NAME:
		var s: StringName = v
		return s
	return default
