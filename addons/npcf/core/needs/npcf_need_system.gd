class_name NpcfNeedSystem
extends RefCounted
## Changes every NPC's needs each tick and emits threshold crossings (R6.1, design "1. World state").


## One tick of need change for every NPC: the need's change_per_tick plus the running action's
## per-tick delta. All changes go through the effect applier.
func tick(world: NpcfWorld) -> void:
	var changes: Array[NpcfStateChange] = []
	for id: StringName in world.npc_ids:
		var npc: NpcfNpcState = world.npc(id)
		if npc == null or npc.resolved == null:
			continue
		for def: NpcfNeedDef in npc.resolved.needs:
			var delta: int = def.change_per_tick
			if npc.is_busy():
				var extra: int = npc.running.def.per_tick_need_deltas.get(def.id, 0)
				delta += extra
			if delta != 0:
				changes.append(NpcfStateChange.need_delta(id, def.id, delta))
	if changes.is_empty():
		return
	var err: String = world.applier.apply(world, changes, -1)
	if err != "":
		push_error("npcf: need tick failed: " + err)


## Stores a need value clamped to its bounds. Unless `quiet`, each threshold crossing emits
## npcf.need_threshold and marks the NPC's decision due.
func set_need(world: NpcfWorld, npc: StringName, need: StringName, value: int, quiet: bool = false) -> void:
	var n: NpcfNpcState = world.npc(npc)
	var def: NpcfNeedDef = world.pack.needs.get(need)
	if n == null or def == null:
		return
	var old: int = n.needs.get(need, def.start)
	var next: int = clampi(value, def.min_value, def.max_value)
	n.needs[need] = next
	if quiet:
		return
	var keys: Array[StringName] = def.thresholds.keys()
	keys.sort_custom(NpcfWorldState.name_less)
	for key: StringName in keys:
		var t: int = def.thresholds[key]
		var down: bool = old >= t and next < t
		var up: bool = old < t and next >= t
		if not down and not up:
			continue
		var e: NpcfEvent = NpcfEvent.new()
		e.kind = NpcfFramework.NEED_THRESHOLD
		e.actors = [npc]
		e.location = world.location_of(npc)
		e.payload = {&"need": need, &"threshold": key, &"direction": &"down" if down else &"up"}
		world.emit(e)
		world.scheduler.mark_due(world, npc, &"need_threshold", false)
