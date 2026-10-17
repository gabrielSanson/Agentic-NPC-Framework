extends NpcfEffectHook
## Fixture: an effect hook, used where a condition hook is required (loader must reject it).


func compute(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> Array[NpcfStateChange]:
	return []
