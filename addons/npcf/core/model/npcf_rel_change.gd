class_name NpcfRelChange
extends RefCounted
## One applied change to a directed relationship value, kept for traces and tests (R11.1).

var tick: int = 0
var holder: StringName = &""
var other: StringName = &""
var dim: StringName = &""
var old_value: int = 0
var new_value: int = 0
var cause_event: int = -1


func to_dict() -> Dictionary:
	return {
		"tick": tick, "holder": String(holder), "other": String(other), "dim": String(dim),
		"old_value": old_value, "new_value": new_value, "cause_event": cause_event,
	}
