extends NpcfConditionHook
## Fixture: calls a method on null at runtime.


func check(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> bool:
	var missing: NpcfNpcView = null
	return missing.npc_id() == &"toy.ana"
