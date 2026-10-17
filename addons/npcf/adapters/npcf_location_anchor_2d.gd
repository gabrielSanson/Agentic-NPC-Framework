class_name NpcfLocationAnchor2D
extends Marker2D
## Where a location's NPCs are placed and walk to. Joins the group npcf_anchors so the runtime can find it.

@export var location_id: StringName


func _ready() -> void:
	add_to_group(&"npcf_anchors")
