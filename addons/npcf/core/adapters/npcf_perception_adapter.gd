class_name NpcfPerceptionAdapter
extends RefCounted
## Decides whether an NPC perceives an event it was not part of (WITNESSED delivery). The base
## class perceives nothing.


func can_perceive(_npc: StringName, _event: NpcfEventView, _world: NpcfWorldView) -> bool:
	return false
