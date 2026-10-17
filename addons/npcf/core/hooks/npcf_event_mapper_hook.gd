class_name NpcfEventMapperHook
extends RefCounted
## Extension point: maps a delivered event to the facts one receiver comes to believe.
## Safe default on failure: no beliefs.


func map_event(_event: NpcfEventView, _receiver: StringName) -> Array[NpcfFact]:
	return []
