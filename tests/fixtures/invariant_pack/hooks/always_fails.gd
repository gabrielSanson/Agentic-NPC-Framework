extends NpcfInvariantHook
## Fixture for the CLI run test: one invariant failure on every tick.


func check(world: NpcfWorldView) -> Array[NpcfInvariantFailure]:
	var out: Array[NpcfInvariantFailure] = []
	out.append(NpcfInvariantFailure.make(&"fixture.inv.broken", world.tick(), [] as Array[StringName], "always fails"))
	return out
