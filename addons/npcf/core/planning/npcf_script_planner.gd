class_name NpcfScriptPlanner
extends NpcfPlanner
## Plans the authored steps of a goal in order, with move prefixes.
## TODO(task 13): not implemented yet; it returns no plan.

## Set by NpcfPlanning right before a call and cleared right after.
var world: NpcfWorld = null


func plan(_goal: NpcfGoalDef, _view: NpcfNpcView, _legal: NpcfLegalActions, _budget: NpcfPlanBudget) -> NpcfPlan:
	return null
