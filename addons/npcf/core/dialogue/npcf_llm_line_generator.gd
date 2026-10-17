class_name NpcfLlmLineGenerator
extends NpcfLineGenerator
## Generated lines through an NpcfLlmTransport, validated before use (R13.5-R13.8). Any failure returns a
## NpcfLineResult with ok = false, so the service emits the authored line instead. Latency is the transport's
## measurement: core code does not read the clock.

var transport: NpcfLlmTransport


func _init(p_transport: NpcfLlmTransport) -> void:
	transport = p_transport


func generate(ctx: NpcfDialogueContext, on_done: Callable) -> void:
	var request: NpcfDialogueRequest = NpcfPromptBuilder.build(ctx)
	if request == null:
		on_done.call(NpcfLineResult.failed(&"no_template"))
		return
	ctx.last_request = request
	transport.send(request, _on_reply.bind(ctx, request, on_done))


func _on_reply(reply: NpcfLlmReply, ctx: NpcfDialogueContext, request: NpcfDialogueRequest, on_done: Callable) -> void:
	if reply.status != &"ok":
		on_done.call(NpcfLineResult.failed(reply.status, reply.latency_ms))
		return
	var r: NpcfLineResult = NpcfLineValidator.check(reply.text, request, ctx)
	r.latency_ms = reply.latency_ms
	on_done.call(r)
