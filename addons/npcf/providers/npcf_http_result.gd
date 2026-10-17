class_name NpcfHttpResult
extends RefCounted
## How a request ended. status: &"ok" (2xx), &"http" (other code, bad reply or connection lost), &"timeout",
## &"refused" (could not connect), &"busy" (queue full), &"dropped" (replaced by a newer request),
## &"down" (provider not ready or gateway closed).

var status: StringName = &"ok"
var code: int = 0
var body: PackedByteArray = []
var latency_ms: int = 0


func text() -> String:
	return body.get_string_from_utf8()


## The body parsed as a JSON object, or {} when it is not one.
func json() -> Dictionary:
	var parsed: Variant = JSON.parse_string(text())
	if parsed is Dictionary:
		var obj: Dictionary = parsed
		return obj
	return {}


static func make(p_status: StringName, p_code: int = 0, p_body: PackedByteArray = PackedByteArray(),
		p_latency_ms: int = 0) -> NpcfHttpResult:
	var r: NpcfHttpResult = NpcfHttpResult.new()
	r.status = p_status
	r.code = p_code
	r.body = p_body
	r.latency_ms = p_latency_ms
	return r
