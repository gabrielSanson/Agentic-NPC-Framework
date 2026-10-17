class_name NpcfWorldView
extends RefCounted
## Read-only view of ground truth for resolver and invariant hooks.

var _world: NpcfWorld


func _init(world: NpcfWorld) -> void:
	_world = world


func tick() -> int:
	return _world.clock.tick


func minute_of_day() -> int:
	return _world.clock.minute_of_day()


func day() -> int:
	return _world.clock.day()


func fact(subject: StringName, fact_id: StringName) -> Variant:
	return _world.state.get_fact(subject, fact_id)


func npc_ids() -> Array[StringName]:
	return _world.npc_ids.duplicate()


func need(npc: StringName, need_id: StringName) -> int:
	var s: NpcfNpcState = _world.npcs.get(npc)
	return s.needs.get(need_id, 0) if s != null else 0


func tags(npc: StringName) -> Array[StringName]:
	var s: NpcfNpcState = _world.npcs.get(npc)
	return s.tags.duplicate() if s != null else []


func location_of(entity: StringName) -> StringName:
	return _world.location_of(entity)


func running_action(npc: StringName) -> StringName:
	var s: NpcfNpcState = _world.npcs.get(npc)
	return s.running.call.action if s != null and s.is_busy() else &""


## IDs of NPCs whose location is `location_id`, sorted.
func npcs_at(location_id: StringName) -> Array[StringName]:
	return _world.occupancy.at(location_id)
