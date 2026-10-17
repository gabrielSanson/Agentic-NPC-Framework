class_name NpcfPlanning
extends RefCounted
## Turns a goal into a plan through the planner the NPC uses (design "3. Planning").
## TODO(task 13): planner dispatch is not implemented yet; every goal is unplannable until then.


static func plan_for(_world: NpcfWorld, _npc: StringName, _goal: NpcfGoalDef) -> NpcfPlan:
	return null
