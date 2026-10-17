class_name NpcfActionOutcome
extends RefCounted
## A started or finished action, reported in the tick report and kept in traces.

var npc: StringName = &""
var action: StringName = &""
var call_id: int = -1
var tick: int = 0
var started_tick: int = 0
## `started`, `success`, or a failure reason (`timeout`, `move_failed`, `cancelled`, `hook_error` ...).
var outcome: StringName = &""
var location: StringName = &""


func to_dict() -> Dictionary:
	return {"npc": String(npc), "action": String(action), "call_id": call_id, "tick": tick,
			"started_tick": started_tick, "outcome": String(outcome), "location": String(location)}
