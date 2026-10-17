class_name NpcfPerceptionAdapter
extends RefCounted
## Decides whether an NPC perceives an event it was not part of (WITNESSED delivery). The base
## class perceives nothing.


func can_perceive(_npc: StringName, _event: NpcfEventView, _world: NpcfWorldView) -> bool:
	return false


## The NPCs that perceive an event, sorted, leaving out `exclude` (the event's participants). The
## default asks can_perceive for every NPC. Adapters with a spatial index override this to ask fewer.
func perceivers(event: NpcfEventView, world: NpcfWorldView, exclude: Dictionary[StringName, int]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in world.npc_ids():
		if exclude.has(id):
			continue
		if can_perceive(id, event, world):
			out.append(id)
	return out


## The NPCs that can hear `entity` speak, sorted. Default: none.
func audible_npcs(_entity: StringName, _world: NpcfWorldView) -> Array[StringName]:
	return []


## The NPC `entity` is facing, or &"". Default: none.
func facing_npc(_entity: StringName, _world: NpcfWorldView) -> StringName:
	return &""
