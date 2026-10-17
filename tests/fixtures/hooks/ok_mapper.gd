extends NpcfEventMapperHook
## Fixture: maps every event to one belief about the receiver's own location.


func map_event(event: NpcfEventView, receiver: StringName) -> Array[NpcfFact]:
	var out: Array[NpcfFact] = []
	out.append(NpcfFact.make(receiver, &"toy.mood", event.kind() == &"npcf.arrived"))
	return out
