class_name NpcfProviderCallRecord
extends RefCounted
## One provider request and how it ended, kept by the gateway for traces (C5c). Holds no headers, so no keys.
## The prompt is set only when the project setting npcf/debug/trace_prompts is on and the kind is text.

var provider: StringName = &""
var kind: StringName = &""
var status: StringName = &""
var latency_ms: int = 0
var fell_back: bool = false
var prompt: String = ""


static func make(p_provider: StringName, p_kind: StringName, p_status: StringName, p_latency_ms: int) -> NpcfProviderCallRecord:
	var r: NpcfProviderCallRecord = NpcfProviderCallRecord.new()
	r.provider = p_provider
	r.kind = p_kind
	r.status = p_status
	r.latency_ms = p_latency_ms
	r.fell_back = p_status != &"ok"
	return r


func to_dict() -> Dictionary:
	return {
		"provider": String(provider), "kind": String(kind), "status": String(status),
		"latency_ms": latency_ms, "fell_back": fell_back, "prompt": prompt,
	}
