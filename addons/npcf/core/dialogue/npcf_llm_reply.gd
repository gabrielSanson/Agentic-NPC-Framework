class_name NpcfLlmReply
extends RefCounted
## What a transport hands back: status &"ok", &"timeout" or &"http"; text is the raw content of the reply.
## latency_ms is the transport's own measurement (0 when it made none).

var status: StringName = &"ok"
var text: String = ""
var latency_ms: int = 0


static func make(p_status: StringName, p_text: String, p_latency_ms: int = 0) -> NpcfLlmReply:
	var r: NpcfLlmReply = NpcfLlmReply.new()
	r.status = p_status
	r.text = p_text
	r.latency_ms = p_latency_ms
	return r
