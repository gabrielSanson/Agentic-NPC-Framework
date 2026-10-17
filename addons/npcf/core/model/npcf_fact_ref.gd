class_name NpcfFactRef
extends RefCounted
## A reference to one fact slot, with the short handle used in dialogue prompts (`f1`, `f2` ...).

var subject: StringName = &""
var fact_id: StringName = &""
var handle: StringName = &""


static func make(p_subject: StringName, p_fact_id: StringName, p_handle: StringName = &"") -> NpcfFactRef:
	var r: NpcfFactRef = NpcfFactRef.new()
	r.subject = p_subject
	r.fact_id = p_fact_id
	r.handle = p_handle
	return r
