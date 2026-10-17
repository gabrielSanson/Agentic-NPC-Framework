extends NpcfConditionHook
## Fixture: returns a null Variant where a bool is required (the typed return fails at runtime).


func check(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> bool:
	var nothing: Variant = null
	return nothing
