extends NpcfEffectHook
## Finishing an exploration adds one discovery to the global count.


func compute(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> Array[NpcfStateChange]:
	var out: Array[NpcfStateChange] = []
	out.append(NpcfStateChange.add_fact(&"npcf.global", &"toy.discoveries", 1))
	return out
