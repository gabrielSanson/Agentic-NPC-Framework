class_name NpcfConsiderationHook
extends RefCounted
## Extension point: a custom utility input. Return a value in 0..1.
## Safe default on failure (error, non-finite or out of range): 0.0.


func evaluate(_view: NpcfNpcView, _params: NpcfHookParams) -> float:
	return 0.0
