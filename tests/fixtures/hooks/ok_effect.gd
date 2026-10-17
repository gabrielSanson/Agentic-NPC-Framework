extends NpcfEffectHook
## Fixture: one ADD_FACT change on the global subject.


func compute(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> Array[NpcfStateChange]:
	var out: Array[NpcfStateChange] = []
	out.append(NpcfStateChange.add_fact(&"npcf.global", &"toy.count", 1))
	return out
