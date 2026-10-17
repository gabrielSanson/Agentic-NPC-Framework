class_name NpcfActionCall
extends RefCounted
## A request to run one action for one NPC with typed arguments.

var call_id: int = -1
var npc: StringName = &""
var action: StringName = &""
var args: Dictionary[StringName, Variant] = {}
var decision_tick: int = 0


static func make(p_npc: StringName, p_action: StringName, p_args: Dictionary[StringName, Variant], p_decision_tick: int) -> NpcfActionCall:
	var c: NpcfActionCall = NpcfActionCall.new()
	c.npc = p_npc
	c.action = p_action
	c.args = p_args
	c.decision_tick = p_decision_tick
	return c


func to_dict() -> Dictionary:
	return {"call_id": call_id, "npc": String(npc), "action": String(action),
			"args": NpcfValueCodec.encode_dict(args), "decision_tick": decision_tick}


func from_dict(_d: Dictionary) -> void:
	pass  # completed in task 21 (save and load)
