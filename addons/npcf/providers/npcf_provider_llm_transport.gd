class_name NpcfProviderLlmTransport
extends NpcfLlmTransport
## Sends LLM line requests through a GENERATE provider. Replies &"http" when the provider is not ready, so the
## service falls back to the authored line.

var gateway: NpcfProviderGateway
var provider_id: StringName


func _init(p_gateway: NpcfProviderGateway, p_provider_id: StringName) -> void:
	gateway = p_gateway
	provider_id = p_provider_id


func send(request: NpcfDialogueRequest, on_done: Callable) -> void:
	var chat: NpcfOpenAiChatAdapter = gateway.adapter(provider_id) as NpcfOpenAiChatAdapter
	if chat == null or not gateway.is_ready(provider_id):
		on_done.call(NpcfLlmReply.make(&"http", ""))
		return
	gateway.send(provider_id, chat.build(gateway.config(provider_id), request), _on_result.bind(chat, on_done))


func _on_result(r: NpcfHttpResult, chat: NpcfOpenAiChatAdapter, on_done: Callable) -> void:
	on_done.call(chat.parse(r))
