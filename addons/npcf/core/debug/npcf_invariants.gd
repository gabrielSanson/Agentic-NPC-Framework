class_name NpcfInvariants
extends RefCounted
## Checks world state after a tick: framework invariants first, then the pack's invariant hooks
## and any extra Callables (tests add inline checks through `extra`).
## Framework IDs: npcf.inv.location, npcf.inv.need_bounds, npcf.inv.running_action.

## Callable(world: NpcfWorld) -> Array[NpcfInvariantFailure].
var extra: Array[Callable] = []


func check(world: NpcfWorld) -> Array[NpcfInvariantFailure]:
	var out: Array[NpcfInvariantFailure] = []
	_framework(world, out)
	for inv: NpcfInvariantDef in world.pack.invariants:
		if inv == null or inv.hook == null:
			continue
		out.append_array(world.hooks.invariant(inv.hook, world.world_view(), inv.id))
	for c: Callable in extra:
		var r: Variant = c.call(world)
		if r is Array:
			var found: Array = r
			for item: Variant in found:
				if item is NpcfInvariantFailure:
					var f: NpcfInvariantFailure = item
					out.append(f)
	return out


func _framework(world: NpcfWorld, out: Array[NpcfInvariantFailure]) -> void:
	for id: StringName in world.npc_ids:
		var npc: NpcfNpcState = world.npc(id)
		if npc == null:
			continue
		var at: StringName = world.location_of(id)
		if not world.pack.location_index.has_location(at):
			out.append(NpcfInvariantFailure.make(&"npcf.inv.location", world.clock.tick, [id],
					"at \"%s\", which is not a known location" % at))
		for need_id: StringName in npc.needs:
			var def: NpcfNeedDef = world.pack.needs.get(need_id)
			var value: int = npc.needs[need_id]
			if def != null and (value < def.min_value or value > def.max_value):
				out.append(NpcfInvariantFailure.make(&"npcf.inv.need_bounds", world.clock.tick, [id],
						"need \"%s\" is %d, outside %d..%d" % [need_id, value, def.min_value, def.max_value]))
		if npc.running != null and npc.running.finished:
			out.append(NpcfInvariantFailure.make(&"npcf.inv.running_action", world.clock.tick, [id],
					"action \"%s\" is finished but still stored as running" % npc.running.call.action))
