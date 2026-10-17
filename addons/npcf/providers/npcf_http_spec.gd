class_name NpcfHttpSpec
extends RefCounted
## One HTTP request to make. path is relative to the endpoint (the gateway adds the endpoint prefix).

var method: HTTPClient.Method = HTTPClient.METHOD_GET
var path: String = "/"
var headers: PackedStringArray = []
var body: PackedByteArray = []
var timeout_ms: int = 2000
