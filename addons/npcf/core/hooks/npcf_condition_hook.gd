class_name NpcfConditionHook
extends RefCounted
## Extension point: a custom condition. Safe default on failure: false.


func check(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> bool:
	return false
