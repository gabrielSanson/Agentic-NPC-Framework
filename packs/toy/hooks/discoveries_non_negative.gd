extends NpcfInvariantHook
## The global discovery count never goes below zero.


func check(world: NpcfWorldView) -> Array[NpcfInvariantFailure]:
	var out: Array[NpcfInvariantFailure] = []
	var value: Variant = world.fact(&"npcf.global", &"toy.discoveries")
	if typeof(value) == TYPE_INT:
		var count: int = value
		if count < 0:
			out.append(NpcfInvariantFailure.make(&"toy.inv.discoveries", world.tick(), [] as Array[StringName],
					"toy.discoveries is %d" % count))
	return out
