class_name NpcfLlmTransport
extends RefCounted
## Sends one request (R13.6). on_done receives one NpcfLlmReply, exactly once. The base class replies &"http".
## Batch C3's provider layer supplies the real implementation; the simulation never waits on it.


func send(_request: NpcfDialogueRequest, on_done: Callable) -> void:
	on_done.call(NpcfLlmReply.make(&"http", ""))
