class_name NpcfAreaPerception2D
extends Area2D
## An NPC's hearing area, a child of its body. Hears a body that overlaps the area, and with line of sight
## only when a ray from the NPC to the body is not blocked.

@export var use_line_of_sight: bool = false
## Optional RayCast2D used for the line-of-sight check.
@export var ray: NodePath


func hears(other: Node2D) -> bool:
	if not overlaps_body(other):
		return false
	if not use_line_of_sight or ray.is_empty():
		return true
	var node: Node = get_node_or_null(ray)
	if node is RayCast2D:
		var r: RayCast2D = node
		r.target_position = other.global_position - global_position
		r.force_raycast_update()
		return not r.is_colliding() or r.get_collider() == other
	return true
