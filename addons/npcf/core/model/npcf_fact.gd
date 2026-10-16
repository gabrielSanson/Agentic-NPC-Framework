class_name NpcfFact
extends RefCounted
## A typed value stored under a fact ID for a subject (global, an entity or a location).

var subject: StringName = &""
var fact_id: StringName = &""
var value: Variant = null


static func make(p_subject: StringName, p_fact_id: StringName, p_value: Variant) -> NpcfFact:
	var f: NpcfFact = NpcfFact.new()
	f.subject = p_subject
	f.fact_id = p_fact_id
	f.value = p_value
	return f


func to_dict() -> Dictionary:
	return {"subject": String(subject), "fact": String(fact_id), "value": NpcfValueCodec.encode(value)}
