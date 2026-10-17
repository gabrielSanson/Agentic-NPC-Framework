class_name NpcfScriptPlanner
extends NpcfPlanner
## Plans the authored steps of a goal in order. Each step is preceded by a move when the NPC must
## travel for it (computed from the location the NPC will be at after the previous step). Only the
## first step must be legal now; later steps are checked again when they start. The plan stops at the
## budget's step limit.

## Set by NpcfPlanning right before a call and cleared right after.
var world: NpcfWorld = null


func plan(goal: NpcfGoalDef, view: NpcfNpcView, legal: NpcfLegalActions, budget: NpcfPlanBudget) -> NpcfPlan:
	if world == null or goal == null or goal.script_steps == null or legal == null or budget == null:
		return null
	var steps: Array[NpcfScriptStep] = goal.script_steps.steps
	if steps.is_empty() or steps[0] == null or steps[0].action == null:
		return null
	if not legal.has(steps[0].action.id):
		return null
	var npc: StringName = view.npc_id()
	var here: StringName = view.location()
	var limit: int = maxi(1, budget.max_steps)
	var plan: NpcfPlan = NpcfPlan.new()
	plan.planner = &"npcf.script"
	for step: NpcfScriptStep in steps:
		if step == null or step.action == null:
			return null
		var a: NpcfActionDef = step.action
		var target: StringName = _target(here, a)
		if _unreachable(here, a):
			return null
		if target != &"" and target != here:
			if plan.steps.size() >= limit:
				return plan
			var move_args: Dictionary[StringName, Variant] = {&"location": target}
			plan.steps.append(NpcfActionCall.make(npc, NpcfFramework.MOVE_TO, move_args, 0))
			here = target
		if plan.steps.size() >= limit:
			return plan
		var args: Dictionary[StringName, Variant] = step.args.duplicate()
		plan.steps.append(NpcfActionCall.make(npc, a.id, args, 0))
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
