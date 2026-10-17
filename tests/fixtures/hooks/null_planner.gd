extends NpcfPlanner
## Fixture: finds no plan. That is a legitimate answer, not a failure.


func plan(_goal: NpcfGoalDef, _view: NpcfNpcView, _legal: NpcfLegalActions, _budget: NpcfPlanBudget) -> NpcfPlan:
	return null
