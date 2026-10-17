class_name NpcfDecisionScheduler
extends RefCounted
## Decides which NPCs decide on a tick: periodic decisions spread by phase, and triggered ones
## marked due by events (design "3. Utility scoring"). Periodic decisions are skipped while the NPC is
## busy. Due entries are taken in (due tick, NPC ID) order, at most `cap` per tick.

## NPC ID -> the entry waiting to be taken.
var _due: Dictionary[StringName, NpcfDueEntry] = {}
## NPC ID -> the entry taken by the latest take_due.
var _taken: Dictionary[StringName, NpcfDueEntry] = {}


## Spreads the NPC's periodic decisions: the first one falls in 1..period at a seeded phase.
func init_npc(world: NpcfWorld, npc: StringName) -> void:
	var n: NpcfNpcState = world.npc(npc)
	if n == null or n.resolved == null:
		return
	var period: int = _period(n)
	var phase: int = world.rng.stream(&"sched", npc, &"phase").randi_range(0, period - 1)
	n.next_periodic_tick = 1 + phase


## Due entries in live order, as rows [npc, due_tick, reason, bypass, rule], for saves.
func export_due() -> Array:
	var out: Array = []
	for npc: StringName in _due:
		var e: NpcfDueEntry = _due[npc]
		out.append([npc, e.due_tick, e.reason, e.bypass, e.rule])
	return out


## Replaces the due entries with saved rows (live order kept) and clears the last take.
func restore_due(rows: Array) -> void:
	_due.clear()
	_taken.clear()
	for row: Array in rows:
		var npc: StringName = row[0]
		var e: NpcfDueEntry = NpcfDueEntry.new()
		e.due_tick = row[1]
		e.reason = row[2]
		e.bypass = row[3]
		e.rule = row[4]
		_due[npc] = e


## Marks the NPC due now. A bypass request also lets the decision skip hysteresis.
func mark_due(world: NpcfWorld, npc: StringName, reason: StringName, bypass: bool, rule: StringName = &"") -> void:
	_add(npc, world.clock.tick, reason, bypass, rule)


## Takes up to `cap` due NPCs, earliest due tick first then by ID. The rest stay due.
func take_due(world: NpcfWorld, cap: int) -> Array[StringName]:
	var tick: int = world.clock.tick
	for id: StringName in world.npc_ids:
		var n: NpcfNpcState = world.npc(id)
		if n == null or n.resolved == null:
			continue
		if tick >= n.next_periodic_tick:
			if not n.is_busy():
				_add(id, n.next_periodic_tick, &"periodic", false, &"")
			var period: int = _period(n)
			while n.next_periodic_tick <= tick:
				n.next_periodic_tick += period
	var ids: Array[StringName] = _due_order(world)
	var out: Array[StringName] = []
	for id: StringName in ids:
		if out.size() >= maxi(0, cap):
			break
		out.append(id)
	for id: StringName in out:
		_taken[id] = _due[id]
		_due.erase(id)
	return out


## The entry the NPC was taken with by the latest take_due, or an empty entry.
func last_taken(npc: StringName) -> NpcfDueEntry:
	var e: NpcfDueEntry = _taken.get(npc)
	if e == null:
		return NpcfDueEntry.new()
	return e


## Keeps the earliest due tick. Reason and rule come from that entry, except that a bypass request
## replaces them when the waiting entry had no bypass. Bypass flags are combined.
func _add(npc: StringName, due_tick: int, reason: StringName, bypass: bool, rule: StringName) -> void:
	var entry: NpcfDueEntry = _due.get(npc)
	if entry == null:
		entry = NpcfDueEntry.new()
		entry.due_tick = due_tick
		entry.reason = reason
		entry.bypass = bypass
		entry.rule = rule
		_due[npc] = entry
		return
	if due_tick < entry.due_tick or (bypass and not entry.bypass):
		entry.due_tick = mini(due_tick, entry.due_tick)
		entry.reason = reason
		entry.rule = rule
	entry.bypass = entry.bypass or bypass


## Every due NPC ID in (due tick, ID) order. World NPC IDs are sorted already, so the IDs are read in that
## order and sorted by an integer key (tick, then position). An ID that is not a world NPC gets the full sort.
func _due_order(world: NpcfWorld) -> Array[StringName]:
	var ids: Array[StringName] = []
	var by_id: Array[StringName] = []
	for id: StringName in world.npc_ids:
		if _due.has(id):
			by_id.append(id)
	if by_id.size() != _due.size():
		ids.assign(_due.keys())
		ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			var ea: NpcfDueEntry = _due[a]
			var eb: NpcfDueEntry = _due[b]
			if ea.due_tick != eb.due_tick:
				return ea.due_tick < eb.due_tick
			return String(a) < String(b))
		return ids
	var n: int = by_id.size()
	var keys: PackedInt64Array = PackedInt64Array()
	for i: int in n:
		var due: int = _due[by_id[i]].due_tick
		keys.append(due * n + i)
	keys.sort()
	for key: int in keys:
		ids.append(by_id[posmod(key, n)])
	return ids


func _period(n: NpcfNpcState) -> int:
	return maxi(1, n.resolved.decision_period_ticks)
