extends NpcfEventMapperHook
## Fixture: returns a null Variant where an array is required (the typed return fails at runtime).


func map_event(_event: NpcfEventView, _receiver: StringName) -> Array[NpcfFact]:
	var nothing: Variant = null
	return nothing
