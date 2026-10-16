class_name NpcfBelief
extends RefCounted
## An NPC's copy of a fact, with its source, confidence and provenance (design "5. Beliefs").

## Where a fact read or a belief came from. TRUTH and DEFAULT appear only on reads.
enum Source { DEFAULT, TRUTH, PARTICIPANT, WITNESSED, TOLD_BY, BROADCAST }

const MAX_TELLERS: int = 4

var subject: StringName = &""
var fact_id: StringName = &""
var value: Variant = null
var confidence: int = 0
var source: int = Source.DEFAULT
var teller: StringName = &""
## Chain of tellers, most recent first, capped at MAX_TELLERS.
var tellers: Array[StringName] = []
var tick: int = 0
var event_id: int = -1
var salience: int = 0


func to_dict() -> Dictionary:
	var source_name: String = Source.keys()[source]
	return {
		"subject": String(subject), "fact": String(fact_id), "value": NpcfValueCodec.encode(value),
		"confidence": confidence, "source": source_name.to_lower(), "teller": String(teller),
		"tellers": NpcfValueCodec.names(tellers), "tick": tick, "event_id": event_id, "salience": salience,
	}


func from_dict(_d: Dictionary) -> void:
	pass  # completed in task 21 (save and load)
