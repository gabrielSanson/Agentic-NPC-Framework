class_name NpcfDecisionRecord
extends RefCounted
## One decision, kept in the NPC's trace ring buffer and printed by the CLI and tests.

var tick: int = 0
var npc: StringName = &""
var reason: StringName = &""
var reaction_rule: StringName = &""
## Ranked, highest score first.
var scores: Array[NpcfScoredGoal] = []
var previous_goal: StringName = &""
var chosen_goal: StringName = &""
var kept: bool = false
var hysteresis_blocked: bool = false
var interrupted: bool = false
## Action IDs of the chosen plan.
var plan: Array[StringName] = []
var rejected: Array[NpcfRejectedGoal] = []
var start_result: StringName = &""


func to_dict() -> Dictionary:
	var score_dicts: Array[Dictionary] = []
	for s: NpcfScoredGoal in scores:
		score_dicts.append(s.to_dict())
	var rejected_dicts: Array[Dictionary] = []
	for r: NpcfRejectedGoal in rejected:
		rejected_dicts.append({"goal": String(r.goal), "reason": String(r.reason)})
	return {
		"tick": tick, "npc": String(npc), "reason": String(reason), "reaction_rule": String(reaction_rule),
		"scores": score_dicts, "previous_goal": String(previous_goal), "chosen_goal": String(chosen_goal),
		"kept": kept, "hysteresis_blocked": hysteresis_blocked, "interrupted": interrupted,
		"plan": NpcfValueCodec.names(plan), "rejected": rejected_dicts, "start_result": String(start_result),
	}
