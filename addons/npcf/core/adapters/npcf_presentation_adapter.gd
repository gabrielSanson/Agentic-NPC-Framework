class_name NpcfPresentationAdapter
extends RefCounted
## Shows running actions to the player. The base class shows nothing (headless runs).


func play(_npc: StringName, _call: NpcfActionCallView) -> void:
	pass


func cancel(_npc: StringName, _call_id: int) -> void:
	pass
