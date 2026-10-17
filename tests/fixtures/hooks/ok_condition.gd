extends NpcfConditionHook
## Fixture: a condition hook that always holds.


func check(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> bool:
	return true
