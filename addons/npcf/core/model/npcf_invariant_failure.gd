class_name NpcfInvariantFailure
extends RefCounted
## One failed invariant check: which invariant, when, which entities, and why.

var invariant_id: StringName = &""
var tick: int = 0
var entities: Array[StringName] = []
var message: String = ""


static func make(p_invariant_id: StringName, p_tick: int, p_entities: Array[StringName], p_message: String) -> NpcfInvariantFailure:
	var f: NpcfInvariantFailure = NpcfInvariantFailure.new()
	f.invariant_id = p_invariant_id
	f.tick = p_tick
	f.entities = p_entities
	f.message = p_message
	return f


func format() -> String:
	return "invariant %s failed at tick %d for [%s]: %s" % [invariant_id, tick, ", ".join(NpcfValueCodec.names(entities)), message]
