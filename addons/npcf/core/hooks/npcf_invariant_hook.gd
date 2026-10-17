class_name NpcfInvariantHook
extends RefCounted
## Extension point: a pack state check. Return one failure per broken rule, or an empty array.
## Safe default on failure: one failure with the message "hook_error".


func check(_world: NpcfWorldView) -> Array[NpcfInvariantFailure]:
	return []
