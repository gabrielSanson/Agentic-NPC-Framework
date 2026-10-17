class_name NpcfFakeLlmTransport
extends NpcfLlmTransport
## Scripted replies for tests. Pops replies in order; an empty queue replies &"http". With deferred = true the
## callbacks wait until flush().

var replies: Array[NpcfLlmReply] = []
var requests: Array[NpcfDialogueRequest] = []
var deferred: bool = false

var _waiting: Array[Callable] = []


func send(request: NpcfDialogueRequest, on_done: Callable) -> void:
	requests.append(request)
	var reply: NpcfLlmReply = replies.pop_front() if not replies.is_empty() else NpcfLlmReply.make(&"http", "")
	if deferred:
		_waiting.append(on_done.bind(reply))
		return
	on_done.call(reply)


## Runs the callbacks held by deferred replies, in the order they were sent.
func flush() -> void:
	var waiting: Array[Callable] = _waiting
	_waiting = []
	for cb: Callable in waiting:
		cb.call()
