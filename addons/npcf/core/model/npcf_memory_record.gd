class_name NpcfMemoryRecord
extends RefCounted
## One entry in an NPC's capped episodic log. Used for dialogue context and traces only (R7.4).

var id: int = -1
var tick: int = 0
var event_id: int = -1
var kind: StringName = &""
var subjects: Array[StringName] = []
var location: StringName = &""
var source: int = NpcfBelief.Source.WITNESSED
var salience: int = 0
var message_key: StringName = &""
var params: Dictionary[StringName, Variant] = {}


func to_dict() -> Dictionary:
	return {
		"id": id, "tick": tick, "event_id": event_id, "kind": String(kind),
		"subjects": NpcfValueCodec.names(subjects), "location": String(location), "source": source,
		"salience": salience, "message_key": String(message_key), "params": NpcfValueCodec.encode_dict(params),
	}


func from_dict(_d: Dictionary) -> void:
	pass  # completed in task 21 (save and load)
