class_name NpcfPresentationAdapter
extends RefCounted
## Shows running actions to the player. The base class shows nothing (headless runs).


func play(_npc: StringName, _call: NpcfActionCallView) -> void:
	pass


func cancel(_npc: StringName, _call_id: int) -> void:
	pass


## True means the game reports completion itself through `Npcf.finish_action`. Only consulted for
## embodied NPCs; a false answer (the default) lets the action finish by its duration.
func holds_completion(_npc: StringName, _call: NpcfActionCallView) -> bool:
	return false
