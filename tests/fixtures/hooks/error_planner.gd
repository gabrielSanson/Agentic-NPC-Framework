extends NpcfPlanner
## Fixture: calls a method on null at runtime.


func plan(_goal: NpcfGoalDef, _view: NpcfNpcView, _legal: NpcfLegalActions, _budget: NpcfPlanBudget) -> NpcfPlan:
	var missing: NpcfPlanBudget = null
	var p: NpcfPlan = NpcfPlan.new()
	p.planner = StringName(str(missing.max_steps))
	return p
