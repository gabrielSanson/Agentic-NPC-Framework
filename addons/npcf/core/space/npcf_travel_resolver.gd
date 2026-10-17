class_name NpcfTravelResolver
extends RefCounted
## Moves NPCs along location paths and records arrivals (R10.3, design "4. Space"). A headless
## mover arrives one edge at a time, after the edge's travel ticks. An embodied mover is walked by
## the movement adapter, which reports each arrival through an input. Every change of `npcf.at`
## goes through move_entity.


## One tick of a move_to action for a headless mover. RUNNING, SUCCESS or FAILURE.
func step(world: NpcfWorld, npc: StringName, ra: NpcfRunningAction) -> int:
	if ra.path_index >= ra.path.size():
		return NpcfResolverHook.SUCCESS
	ra.edge_elapsed += 1
	var target: StringName = ra.path[ra.path_index]
	var edge: int = world.pack.location_index.edge_ticks(ra.last_location, target)
	if edge < 0:
		return NpcfResolverHook.FAILURE
	if ra.edge_elapsed >= edge:
		move_entity(world, npc, target)
		ra.last_location = target
		ra.path_index += 1
		ra.edge_elapsed = 0
	if ra.path_index >= ra.path.size():
		return NpcfResolverHook.SUCCESS
	return NpcfResolverHook.RUNNING


## An entity reached a location (reported by an embodied mover or the player). Moves it there. An NPC
## whose move_to target this is finishes its move.
func on_arrived(world: NpcfWorld, entity: StringName, location: StringName) -> void:
	move_entity(world, entity, location)
	var n: NpcfNpcState = world.npc(entity)
	if n == null or n.running == null:
		return
	var ra: NpcfRunningAction = n.running
	if ra.finished or ra.call.action != NpcfFramework.MOVE_TO:
		return
	if ra.path_index < ra.path.size() and ra.path[ra.path_index] == location:
		ra.path_index += 1
		ra.edge_elapsed = 0
	ra.last_location = location
	var target: StringName = ra.call.args.get(&"location", &"")
	if location == target:
		world.executor.finish(world, entity, true, &"success")


## An NPC became embodied or disembodied. A move in progress hands its remaining path to the
## movement adapter, or resumes headless with a fresh edge timer. Start effects never run again.
func on_embodiment(world: NpcfWorld, npc: StringName, embodied: bool) -> void:
	var n: NpcfNpcState = world.npc(npc)
	if n == null or n.running == null:
		return
	var ra: NpcfRunningAction = n.running
	if ra.finished or ra.embodied == embodied:
		return
	ra.embodied = embodied
	if ra.call.action != NpcfFramework.MOVE_TO:
		return
	if embodied:
		var remaining: Array[StringName] = []
		for i: int in range(ra.path_index, ra.path.size()):
			remaining.append(ra.path[i])
		world.adapters.movement.move_along(npc, ra.call.call_id, remaining)
	else:
		ra.edge_elapsed = 0


## Sets an entity's location: emits departed from the old location (when it had one), writes
## `npcf.at`, then emits arrived at the new one. Does nothing when the entity is already there.
func move_entity(world: NpcfWorld, entity: StringName, to: StringName) -> void:
	var old: StringName = world.location_of(entity)
	if old == to:
		return
	if old != &"":
		var departed: NpcfEvent = NpcfEvent.new()
		departed.kind = NpcfFramework.DEPARTED
		departed.actors = [entity]
		departed.location = old
		world.emit(departed)
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(entity, NpcfFramework.AT, to)]
	var err: String = world.applier.apply(world, changes, -1)
	if err != "":
		push_error("npcf: moving %s to %s failed: %s" % [entity, to, err])
		return
	var arrived: NpcfEvent = NpcfEvent.new()
	arrived.kind = NpcfFramework.ARRIVED
	arrived.actors = [entity]
	arrived.location = to
	world.emit(arrived)
