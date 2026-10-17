class_name NpcfIntentResult
extends RefCounted
## What a classifier returns. `source` is &"keyword", &"provider" or anything a classifier names.

var intent: StringName = &""
var confidence: float = 0.0
var source: StringName = &""


static func make(p_intent: StringName, p_confidence: float, p_source: StringName) -> NpcfIntentResult:
	var r: NpcfIntentResult = NpcfIntentResult.new()
	r.intent = p_intent
	r.confidence = p_confidence
	r.source = p_source
	return r
