extends NpcfEffectHook
## Fixture: calls a method on null at runtime.


func compute(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> Array[NpcfStateChange]:
	var missing: NpcfNpcView = null
	var out: Array[NpcfStateChange] = []
	out.append(NpcfStateChange.add_fact(missing.npc_id(), &"toy.count", 1))
	return out
