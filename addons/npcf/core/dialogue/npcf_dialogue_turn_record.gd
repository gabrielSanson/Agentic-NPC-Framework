class_name NpcfDialogueTurnRecord
extends RefCounted
## What one dialogue turn decided, kept on the service for traces and tests (R17.2). Holds no player text.

var line_id: int = -1
var tick: int = 0
var npc: StringName = &""
## named, facing, last_talked or only_candidate (the addressee was picked); otherwise the refusal reason.
var addressee_reason: StringName = &""
var intent: StringName = &""
var confidence: float = 0.0
var classifier_source: StringName = &""
var fell_back: bool = false
var result: StringName = &""
## "subject/fact" for each revealed fact, and for each reveal that was dropped.
var revealed: Array[String] = []
var dropped_reveals: Array[String] = []
var variant: StringName = &""
## "handle=subject/fact" for each fact put in the prompt.
var injected_facts: Array[String] = []
var injected_memories: Array[int] = []
var offered_actions: Array[StringName] = []
var llm_status: StringName = &"off"
var latency_ms: int = 0
var failure: StringName = &""
var validation_failures: Array[StringName] = []
## "authored" or "llm".
var line_source: StringName = &"authored"
## The dialogue-tier action requested by the line, or &"".
var action: StringName = &""
var presentation: Dictionary[StringName, StringName] = {}


## The record as a dictionary with its keys in sorted order.
func to_dict() -> Dictionary:
	var pres: Dictionary = {}
	var keys: Array[StringName] = []
	keys.assign(presentation.keys())
	keys.sort_custom(NpcfWorldState.name_less)
	for k: StringName in keys:
		pres[String(k)] = String(presentation[k])
	return {
		"action": String(action),
		"addressee_reason": String(addressee_reason),
		"classifier_source": String(classifier_source),
		"confidence": confidence,
		"dropped_reveals": dropped_reveals.duplicate(),
		"failure": String(failure),
		"fell_back": fell_back,
		"injected_facts": injected_facts.duplicate(),
		"injected_memories": injected_memories.duplicate(),
		"intent": String(intent),
		"latency_ms": latency_ms,
		"line_id": line_id,
		"line_source": String(line_source),
		"llm_status": String(llm_status),
		"npc": String(npc),
		"offered_actions": NpcfValueCodec.names(offered_actions),
		"presentation": pres,
		"result": String(result),
		"revealed": revealed.duplicate(),
		"tick": tick,
		"validation_failures": NpcfValueCodec.names(validation_failures),
		"variant": String(variant),
	}
