class_name NpcfLocationArea2D
extends Area2D
## Reports arrivals at a location: the player's location for the player body, and an arrival for each NPC
## body that carries an NpcfAgent2D child. Leaving the area changes nothing.

@export var location_id: StringName
@export var runtime_path: NodePath = ^"/root/Npcf"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var node: Node = get_node_or_null(runtime_path)
	if not node is NpcfRuntime:
		return
	var rt: NpcfRuntime = node
	if body.is_in_group(&"npcf_player"):
		rt.report_player_location(location_id)
		return
	for child: Node in body.get_children():
		if child is NpcfAgent2D:
			var agent: NpcfAgent2D = child
			rt.report_arrived(agent.npc_id, location_id)
			return
