class_name NpcfFactRead
extends RefCounted
## The result of reading a fact through an NPC's view: the value, a confidence 0..100 and where it
## came from (an NpcfBelief.Source value).

var value: Variant = null
var confidence: int = 0
var source: int = NpcfBelief.Source.DEFAULT


static func make(p_value: Variant, p_confidence: int, p_source: int) -> NpcfFactRead:
	var r: NpcfFactRead = NpcfFactRead.new()
	r.value = p_value
	r.confidence = p_confidence
	r.source = p_source
	return r
