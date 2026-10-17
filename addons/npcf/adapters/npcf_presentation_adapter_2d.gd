class_name NpcfPresentationAdapter2D
extends NpcfPresentationAdapter
## Shows actions through the NPC's agent signals. The game plays the animation and, when the agent says
## so (game_finishes_actions), reports completion back through Npcf.finish_action.

var registry: NpcfAgentRegistry2D


func _init(p_registry: NpcfAgentRegistry2D) -> void:
	registry = p_registry


func play(npc: StringName, call: NpcfActionCallView) -> void:
	var a: NpcfAgent2D = registry.agent(npc)
	if a != null:
		a.play_action.emit(call.call_id(), call.action(), call.presentation_cue(), call.duration_ticks())


func cancel(npc: StringName, call_id: int) -> void:
	var a: NpcfAgent2D = registry.agent(npc)
	if a != null:
		a.action_cancelled.emit(call_id)


func holds_completion(npc: StringName, _call: NpcfActionCallView) -> bool:
	var a: NpcfAgent2D = registry.agent(npc)
	return a != null and a.game_finishes_actions
