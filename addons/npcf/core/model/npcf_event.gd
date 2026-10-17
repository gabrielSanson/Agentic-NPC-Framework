class_name NpcfEvent
extends RefCounted
## A committed event. Payload values are validated against the event kind's fields on emit.

## Who receives an event besides its participants (NpcfEventKindDef.visibility mirrors this).
enum Visibility { LOCAL, PUBLIC, PARTICIPANTS_ONLY }

var id: int = -1
var tick: int = 0
var kind: StringName = &""
var actors: Array[StringName] = []
var targets: Array[StringName] = []
var location: StringName = &""
var payload: Dictionary[StringName, Variant] = {}
var salience: int = 0
var visibility: int = Visibility.LOCAL


func to_dict() -> Dictionary:
	return {
		"id": id, "tick": tick, "kind": String(kind), "actors": NpcfValueCodec.names(actors),
		"targets": NpcfValueCodec.names(targets), "location": String(location),
		"payload": NpcfValueCodec.encode_dict(payload), "salience": salience, "visibility": visibility,
	}


func from_dict(_d: Dictionary) -> void:
	pass  # completed in task 21 (save and load)
