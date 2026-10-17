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


## Save form: argument values are tagged (see NpcfSaveCodec); pairs keep live order.
func to_save() -> Dictionary:
	var rows: Array = []
	for k: StringName in args:
		rows.append([String(k), NpcfSaveCodec.encode_value(args[k], "action args")])
	return {"call_id": call_id, "npc": String(npc), "action": String(action), "args": rows,
			"decision_tick": decision_tick}


## Reads a call written by to_save. Action IDs the pack does not define fail the reader.
static func from_save(r: NpcfSaveCodec.Reader, d: Variant, path: String) -> NpcfActionCall:
	var c: NpcfActionCall = NpcfActionCall.new()
	c.call_id = r.int_at(d, "call_id", path)
	c.npc = r.name_at(d, "npc", path)
	c.action = r.name_at(d, "action", path)
	if not r.known_actions.has(c.action):
		r.fail("%s: unknown action %s" % [path, c.action])
	for row: Variant in r.arr_at(d, "args", path):
		var kv: Array = r.pair_v(row, path + ".args")
		var key: StringName = r.name_v(kv[0], path + ".args")
		c.args[key] = r.value_v(kv[1], path + ".args")
	c.decision_tick = r.int_at(d, "decision_tick", path)
	return c
