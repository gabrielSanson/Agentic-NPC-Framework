extends NpcfEffectHook
## Fixture: returns an array of ints through a Variant, where changes are required.


func compute(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> Array[NpcfStateChange]:
	var v: Variant = [7, 8]
	return v
