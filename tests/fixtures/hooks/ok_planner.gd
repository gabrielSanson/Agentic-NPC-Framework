extends NpcfPlanner
## Fixture: returns an empty plan with a trace name.


func plan(_goal: NpcfGoalDef, _view: NpcfNpcView, _legal: NpcfLegalActions, _budget: NpcfPlanBudget) -> NpcfPlan:
	var p: NpcfPlan = NpcfPlan.new()
	p.planner = &"toy.fixture"
	return p
