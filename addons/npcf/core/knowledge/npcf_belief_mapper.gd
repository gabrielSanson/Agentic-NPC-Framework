class_name NpcfBeliefMapper
extends RefCounted
## Maps a delivered event to the facts one receiver comes to believe (design "5. Beliefs").
## TODO(task 9): framework kinds and declarative fact templates are not mapped yet; until then
## every event maps to no beliefs.


static func map(_world: NpcfWorld, _e: NpcfEvent, _receiver: StringName) -> Array[NpcfFact]:
	return []
