class_name NpcfReactionRules
extends RefCounted
## Reactions: a delivered event can add a personal directive and make the NPC decide at once (R8.3).
## TODO(task 17): reactions are not implemented yet; delivery never calls this.


func on_delivery(_world: NpcfWorld, _npc: StringName, _e: NpcfEvent, _source: int) -> void:
	pass
