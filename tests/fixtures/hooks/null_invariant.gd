extends NpcfInvariantHook
## Fixture: returns a null Variant where an array is required (the typed return fails at runtime).


func check(_world: NpcfWorldView) -> Array[NpcfInvariantFailure]:
	var nothing: Variant = null
	return nothing
