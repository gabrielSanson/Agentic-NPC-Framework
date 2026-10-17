class_name NpcfUtilityScorer
extends RefCounted
## Scores goals and actions with compensated utility (design "3. Utility scoring").
## TODO(task 12): consideration inputs and scoring are not implemented yet. The methods return
## neutral values (0.0 inputs, unscored goals) until then.


## Compensation of a list of values: k = 0 gives 1, otherwise the compensated product.
static func compensate(values: Array[float]) -> float:
	var k: int = values.size()
	if k == 0:
		return 1.0
	var m: float = 1.0 - 1.0 / float(k)
	var product: float = 1.0
	for v: float in values:
		product *= v + (1.0 - v) * m * v
	return product


func input(_world: NpcfWorld, _view: NpcfNpcView, _c: NpcfConsiderationDef, _goal_id: StringName) -> float:
	return 0.0


func score(_world: NpcfWorld, _view: NpcfNpcView, goal: NpcfGoalDef) -> NpcfScoredGoal:
	var s: NpcfScoredGoal = NpcfScoredGoal.new()
	s.goal = goal.id
	return s


func score_action(_world: NpcfWorld, _view: NpcfNpcView, _a: NpcfActionDef) -> float:
	return 0.0
