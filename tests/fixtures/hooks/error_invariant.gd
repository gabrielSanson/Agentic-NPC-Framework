extends NpcfInvariantHook
## Fixture: calls a method on null at runtime.


func check(_world: NpcfWorldView) -> Array[NpcfInvariantFailure]:
	var missing: NpcfWorldView = null
	var out: Array[NpcfInvariantFailure] = []
	if missing.tick() < 0:
		out.append(NpcfInvariantFailure.make(&"toy.inv.x", 0, [] as Array[StringName], "never"))
	return out
