class_name NpcfSingleStepPlanner
extends NpcfPlanner
## The default planner: one legal action per goal, preceded by a move when the NPC is elsewhere.
## Among the legal candidates of the goal, the best by action score (ties by ID) is chosen. An action
## whose location cannot be reached is skipped.

## Set by NpcfPlanning right before a call and cleared right after.
var world: NpcfWorld = null


func plan(goal: NpcfGoalDef, view: NpcfNpcView, legal: NpcfLegalActions, _budget: NpcfPlanBudget) -> NpcfPlan:
	if world == null or goal == null or legal == null:
		return null
	var here: StringName = view.location()
	var best: NpcfActionDef = null
	var best_score: float = 0.0
	for a: NpcfActionDef in legal.actions:
		if not goal.candidate_actions.has(a):
			continue
		if _unreachable(here, a):
			continue
		var s: float = world.scorer.score_action(world, view, a)
		if best == null or s > best_score or (s == best_score and String(a.id) < String(best.id)):
			best = a
			best_score = s
	if best == null:
		return null

	var npc: StringName = view.npc_id()
	var plan: NpcfPlan = NpcfPlan.new()
	plan.planner = &"npcf.single_step"
	var target: StringName = _target(here, best)
	if target != &"" and target != here:
		var move_args: Dictionary[StringName, Variant] = {&"location": target}
		plan.steps.append(NpcfActionCall.make(npc, NpcfFramework.MOVE_TO, move_args, 0))
	var no_args: Dictionary[StringName, Variant] = {}
	plan.steps.append(NpcfActionCall.make(npc, best.id, no_args, 0))
	return plan


## Where an action must be done from `here`: its required location, or the nearest location with its
## required tag. &"" when the action has no location requirement or the tag is nowhere.
func _target(here: StringName, a: NpcfActionDef) -> StringName:
	if a.required_location != null:
		return a.required_location.id
	if a.required_location_tag != &"":
		return world.pack.location_index.nearest_with_tag(here, a.required_location_tag)
	return &""


func _unreachable(here: StringName, a: NpcfActionDef) -> bool:
	if a.required_location != null:
		return world.pack.location_index.travel_ticks(here, a.required_location.id) < 0
	if a.required_location_tag != &"":
		return world.pack.location_index.nearest_with_tag(here, a.required_location_tag) == &""
	return false
