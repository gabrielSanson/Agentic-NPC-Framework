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


## Save form: the value is tagged (see NpcfSaveCodec).
func to_save() -> Dictionary:
	return {
		"subject": String(subject), "fact": String(fact_id),
		"value": NpcfSaveCodec.encode_value(value, "belief value"), "confidence": confidence,
		"source": source, "teller": String(teller), "tellers": NpcfValueCodec.names(tellers),
		"tick": tick, "event_id": event_id, "salience": salience,
	}


## Reads a belief written by to_save.
static func from_save(r: NpcfSaveCodec.Reader, d: Variant, path: String) -> NpcfBelief:
	var b: NpcfBelief = NpcfBelief.new()
	b.subject = r.name_at(d, "subject", path)
	b.fact_id = r.name_at(d, "fact", path)
	b.value = r.value_at(d, "value", path)
	b.confidence = r.int_at(d, "confidence", path)
	b.source = r.int_at(d, "source", path)
	b.teller = r.name_at(d, "teller", path)
	b.tellers = r.names_at(d, "tellers", path)
	b.tick = r.int_at(d, "tick", path)
	b.event_id = r.int_at(d, "event_id", path)
	b.salience = r.int_at(d, "salience", path)
	return b
