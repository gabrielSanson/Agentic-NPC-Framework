class_name NpcfGoalSelector
extends RefCounted
## Picks an NPC's goal when it is due and starts its plan (design "3. Utility scoring"). Goals are
## ranked by utility (ties by goal ID). The current goal is kept unless the best goal beats it by its
## hysteresis, the decision bypasses hysteresis, or the best goal's interrupt holds. The chosen goal is
## planned and started; when that fails the goal cools down and the next candidate is tried.

## Shared empty args for conditions. Never mutate it.
static var _NO_ARGS: Dictionary[StringName, Variant] = {}


## Decides one NPC's goal. Returns the record, which is also kept in the NPC's decision ring buffer.
func decide(world: NpcfWorld, npc: StringName, report: NpcfTickReport = null) -> NpcfDecisionRecord:
	if world.audit != null:
		world.audit.begin(&"decision")
	var record: NpcfDecisionRecord = _decide(world, npc, report)
	if world.audit != null:
		world.audit.end()
	return record


func _decide(world: NpcfWorld, npc: StringName, report: NpcfTickReport) -> NpcfDecisionRecord:
	var record: NpcfDecisionRecord = NpcfDecisionRecord.new()
	record.tick = world.clock.tick
	record.npc = npc
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return record
	var due: NpcfDueEntry = world.scheduler.last_taken(npc)
	record.reason = due.reason
	record.reaction_rule = due.rule
	record.previous_goal = n.current_goal
	record.scores = rank(world, npc, record)

	var candidates: Array[NpcfScoredGoal] = []
	for s: NpcfScoredGoal in record.scores:
		if s.score > 0.0:
			candidates.append(s)
	if candidates.is_empty():
		n.current_goal = &""
		_store(world, n, record)
		return record

	var view: NpcfNpcView = world.view(npc)
	var current: StringName = n.current_goal
	var current_score: NpcfScoredGoal = null
	for s: NpcfScoredGoal in candidates:
		if s.goal == current:
			current_score = s
	var best: NpcfScoredGoal = candidates[0]
	var chosen: StringName = best.goal
	var kept: bool = false
	if current_score != null and best.goal != current:
		var current_def: NpcfGoalDef = _goal_def(n, current)
		var hysteresis: float = current_def.hysteresis if current_def != null else 0.0
		var best_def: NpcfGoalDef = _goal_def(n, best.goal)
		var interrupted: bool = best_def != null and best_def.interrupt != null \
				and NpcfConditions.check(world, view, best_def.interrupt, _NO_ARGS, false)
		var beats: bool = best.score > current_score.score * (1.0 + hysteresis)
		if beats or due.bypass or interrupted:
			record.interrupted = interrupted and not beats and not due.bypass
		else:
			chosen = current
			kept = true
			record.hysteresis_blocked = true
	elif current_score != null:
		kept = true
	record.kept = kept

	if kept and n.is_busy():
		record.chosen_goal = current
		_store(world, n, record)
		return record

	# The chosen goal first, then the other candidates in rank order.
	var order: Array[StringName] = [chosen]
	for s: NpcfScoredGoal in candidates:
		if s.goal != chosen:
			order.append(s.goal)
	record.chosen_goal = &""
	var planning: NpcfPlanning.Session = NpcfPlanning.Session.new(world, npc)
	for g: StringName in order:
		var goal: NpcfGoalDef = _goal_def(n, g)
		if goal == null:
			continue
		var plan: NpcfPlan = planning.plan_for(goal)
		if plan == null or plan.is_empty():
			_cool_down(world, n, goal)
			record.rejected.append(NpcfRejectedGoal.make(g, &"no_plan"))
			continue
		for step: NpcfActionCall in plan.steps:
			record.plan.append(step.action)
		if n.is_busy():
			world.executor.cancel(world, npc, &"goal_switch", report)
		var result: StringName = world.executor.start_plan(world, npc, plan, report)
		record.start_result = result
		if result != NpcfExecutor.OK:
			_cool_down(world, n, goal)
			record.rejected.append(NpcfRejectedGoal.make(g, result))
			record.plan.clear()
			continue
		n.current_goal = g
		record.chosen_goal = g
		break
	if record.chosen_goal == &"":
		n.current_goal = &""
	_store(world, n, record)
	return record


## The goals of the NPC that are not cooling down, scored and sorted by utility (highest first, ties
## by goal ID). Goals in cooldown are added to the record as rejected.
func rank(world: NpcfWorld, npc: StringName, record: NpcfDecisionRecord) -> Array[NpcfScoredGoal]:
	var out: Array[NpcfScoredGoal] = []
	var n: NpcfNpcState = world.npc(npc)
	if n == null or n.resolved == null:
		return out
	var tick: int = world.clock.tick
	var view: NpcfNpcView = world.view(npc)
	for goal: NpcfGoalDef in n.resolved.goals:
		if goal == null:
			continue
		if n.unreachable_until.get(goal.id, 0) > tick:
			record.rejected.append(NpcfRejectedGoal.make(goal.id, &"unreachable_cooldown"))
			continue
		out.append(world.scorer.score(world, view, goal))
	out.sort_custom(func(a: NpcfScoredGoal, b: NpcfScoredGoal) -> bool:
		if a.score != b.score:
			return a.score > b.score
		return String(a.goal) < String(b.goal))
	return out


func _goal_def(n: NpcfNpcState, id: StringName) -> NpcfGoalDef:
	if n.resolved == null:
		return null
	for goal: NpcfGoalDef in n.resolved.goals:
		if goal != null and goal.id == id:
			return goal
	return null


func _cool_down(world: NpcfWorld, n: NpcfNpcState, goal: NpcfGoalDef) -> void:
	n.unreachable_until[goal.id] = world.clock.tick + goal.unreachable_cooldown_ticks


## Keeps the record in the NPC's ring buffer, up to the sim's decision_records.
func _store(world: NpcfWorld, n: NpcfNpcState, record: NpcfDecisionRecord) -> void:
	n.decision_records.append(record)
	var cap: int = maxi(1, world.sim.decision_records)
	while n.decision_records.size() > cap:
		n.decision_records.pop_front()
