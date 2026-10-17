class_name NpcfMovementAdapter
extends RefCounted
## Presentation-side movement. An embodied NPC walks its path itself and reports arrivals through
## inputs. This base class is headless: nothing is embodied and nothing moves.


func is_embodied(_npc: StringName) -> bool:
	return false


func move_along(_npc: StringName, _call_id: int, _path: Array[StringName]) -> void:
	pass


func stop(_npc: StringName) -> void:
	pass
