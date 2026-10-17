extends NpcfEventMapperHook
## Fixture: calls a method on null at runtime.


func map_event(_event: NpcfEventView, _receiver: StringName) -> Array[NpcfFact]:
	var missing: NpcfEventView = null
	var out: Array[NpcfFact] = []
	out.append(NpcfFact.make(missing.kind(), &"toy.mood", true))
	return out
