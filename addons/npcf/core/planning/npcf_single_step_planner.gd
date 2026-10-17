class_name NpcfSingleStepPlanner
extends NpcfPlanner
## The default planner: one legal action per goal, preceded by a move when the NPC is elsewhere.
## TODO(task 13): not implemented yet; it returns no plan.

## Set by NpcfPlanning right before a call and cleared right after.
var world: NpcfWorld = null


func plan(_goal: NpcfGoalDef, _view: NpcfNpcView, _legal: NpcfLegalActions, _budget: NpcfPlanBudget) -> NpcfPlan:
	return null
