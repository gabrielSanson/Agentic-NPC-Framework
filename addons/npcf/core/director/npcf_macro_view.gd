class_name NpcfMacroView
extends RefCounted
## Read-only view of the Director's macro variables, for Director hooks. Filled in task 18.

var _values: Dictionary[StringName, float] = {}


func value(id: StringName) -> float:
	return _values.get(id, 0.0)


func ids() -> Array[StringName]:
	var out: Array[StringName] = _values.keys()
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out
