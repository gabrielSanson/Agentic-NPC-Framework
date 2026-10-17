class_name NpcfMovementAdapter2D
extends NpcfMovementAdapter
## Walks embodied NPCs with their agents' movers. An NPC without a registered agent is never embodied.

var registry: NpcfAgentRegistry2D


func _init(p_registry: NpcfAgentRegistry2D) -> void:
	registry = p_registry


func is_embodied(npc: StringName) -> bool:
	return registry.agent(npc) != null


func move_along(npc: StringName, call_id: int, path: Array[StringName]) -> void:
	if path.is_empty():
		return
	var m: NpcfNavMover2D = _mover(npc)
	if m != null:
		m.walk(call_id, path)


func stop(npc: StringName) -> void:
	var m: NpcfNavMover2D = _mover(npc)
	if m != null:
		m.halt()


func _mover(npc: StringName) -> NpcfNavMover2D:
	var a: NpcfAgent2D = registry.agent(npc)
	return a.mover() if a != null else null
