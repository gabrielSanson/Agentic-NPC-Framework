class_name NpcfLineGenerator
extends RefCounted
## Produces the spoken line for a turn. The base class returns failure &"off", so the service emits the authored
## line. on_done receives one NpcfLineResult, exactly once.


func generate(_ctx: NpcfDialogueContext, on_done: Callable) -> void:
	on_done.call(NpcfLineResult.failed(&"off"))
