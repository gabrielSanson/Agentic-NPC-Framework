class_name NpcfGoalSelector
extends RefCounted
## Picks an NPC's goal when it is due and starts its plan (design "3. Utility scoring").
## TODO(task 12): ranking, hysteresis and plan start are not implemented yet. A decision currently
## records nothing and keeps the NPC's goal.


func decide(world: NpcfWorld, npc: StringName, _report: NpcfTickReport = null) -> NpcfDecisionRecord:
	var record: NpcfDecisionRecord = NpcfDecisionRecord.new()
	record.tick = world.clock.tick
	record.npc = npc
	var n: NpcfNpcState = world.npc(npc)
	if n != null:
		record.previous_goal = n.current_goal
		record.chosen_goal = n.current_goal
		record.kept = true
	return record


func rank(_world: NpcfWorld, _npc: StringName, _record: NpcfDecisionRecord) -> Array[NpcfScoredGoal]:
	return []
