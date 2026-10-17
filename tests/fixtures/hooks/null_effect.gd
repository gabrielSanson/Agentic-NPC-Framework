extends NpcfEffectHook
## Fixture: returns a null Variant where an array is required (the typed return fails at runtime).


func compute(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> Array[NpcfStateChange]:
	var nothing: Variant = null
	return nothing
