class_name NpcfTravelResolver
extends RefCounted
## Moves NPCs along location paths and records arrivals (R10.3, design "4. Space").
## TODO(task 11): travel steps, arrival handling and embodiment are not implemented yet. The stubs
## keep the world loop running and report a failed step.


## RUNNING, SUCCESS or FAILURE for one tick of a move_to action (NpcfResolverHook constants).
func step(_world: NpcfWorld, _npc: StringName, _ra: NpcfRunningAction) -> int:
	return NpcfResolverHook.FAILURE


func on_arrived(_world: NpcfWorld, _entity: StringName, _location: StringName) -> void:
	pass


func on_embodiment(_world: NpcfWorld, _npc: StringName, _embodied: bool) -> void:
	pass


func move_entity(_world: NpcfWorld, _entity: StringName, _to: StringName) -> void:
	pass
