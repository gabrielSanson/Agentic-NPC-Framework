class_name NpcfOpenAiChatAdapter
extends NpcfProviderAdapter
## The OpenAI-compatible chat server (llama.cpp llama-server in the demo) for GENERATE: line requests as
## POST /v1/chat/completions. Health is GET /v1/models, and only a 2xx answer counts as up.


func kind() -> NpcfProviderConfig.Kind:
	return NpcfProviderConfig.Kind.GENERATE


func health_spec(cfg: NpcfProviderConfig) -> NpcfHttpSpec:
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = HTTPClient.METHOD_GET
	s.path = "/v1/models"
	s.timeout_ms = cfg.health_timeout_ms
	return s


func health_ok(r: NpcfHttpResult) -> bool:
	return r.status == &"ok"


func build(cfg: NpcfProviderConfig, req: NpcfDialogueRequest) -> NpcfHttpSpec:
	var messages: Array[Dictionary] = []
	for m: NpcfChatMessage in req.messages:
		messages.append({"role": str(m.role), "content": m.content})
	var d: Dictionary = {
		"messages": messages,
		"temperature": req.temperature,
		"max_tokens": req.max_tokens,
		"stream": false,
	}
	if cfg.model != "":
		d["model"] = cfg.model
	var json_schema_on: bool = cfg.extra.get(&"json_schema", true)
	if req.structured_output and not req.schema.is_empty() and json_schema_on:
		d["response_format"] = {
			"type": "json_schema",
			"json_schema": {"name": "npc_line", "strict": true, "schema": req.schema},
		}
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = HTTPClient.METHOD_POST
	s.path = "/v1/chat/completions"
	s.headers = PackedStringArray(["Content-Type: application/json"])
	s.body = JSON.stringify(d).to_utf8_buffer()
	s.timeout_ms = cfg.effective_timeout_ms()
	return s


func parse(r: NpcfHttpResult) -> NpcfLlmReply:
	if r.status == &"timeout":
		return NpcfLlmReply.make(&"timeout", "", r.latency_ms)
	if r.status != &"ok":
		return NpcfLlmReply.make(&"http", "", r.latency_ms)
	var data: Dictionary = r.json()
	var choices: Variant = data.get("choices")
	if not (choices is Array):
		return NpcfLlmReply.make(&"http", "", r.latency_ms)
	var list: Array = choices
	if list.is_empty() or not (list[0] is Dictionary):
		return NpcfLlmReply.make(&"http", "", r.latency_ms)
	var first: Dictionary = list[0]
	var message: Variant = first.get("message")
	if not (message is Dictionary):
		return NpcfLlmReply.make(&"http", "", r.latency_ms)
	var msg: Dictionary = message
	var content: Variant = msg.get("content")
	if not (content is String):
		return NpcfLlmReply.make(&"http", "", r.latency_ms)
	var text: String = content
	return NpcfLlmReply.make(&"ok", text, r.latency_ms)
