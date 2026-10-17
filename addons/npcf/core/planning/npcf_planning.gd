class_name NpcfPlanning
extends RefCounted
## Turns a goal into a plan through the planner the NPC uses (design "3. Planning"). Legal actions are
## computed from the NPC's own view; every call of the plan is stamped with the decision tick.


## The plan for one goal, or null when the NPC's planner finds none.
static func plan_for(world: NpcfWorld, npc: StringName, goal: NpcfGoalDef) -> NpcfPlan:
	var n: NpcfNpcState = world.npc(npc)
	if n == null or n.resolved == null or goal == null:
		return null
	var view: NpcfNpcView = world.view(npc)
	var candidates: Array[NpcfActionDef] = []
	for a: NpcfActionDef in goal.candidate_actions:
		if a != null and not candidates.has(a):
			candidates.append(a)
	if goal.script_steps != null:
		for step: NpcfScriptStep in goal.script_steps.steps:
			if step != null and step.action != null and not candidates.has(step.action):
				candidates.append(step.action)
	var legal: NpcfLegalActions = world.action_registry.legal_for(world, view, candidates)
	var budget: NpcfPlanBudget = NpcfPlanBudget.new()
	var ref: NpcfPlannerRef = n.resolved.planner
	var kind: NpcfPlannerRef.Kind = ref.kind if ref != null else NpcfPlannerRef.Kind.SINGLE_STEP
	var plan: NpcfPlan = null
	match kind:
		NpcfPlannerRef.Kind.SCRIPT:
			var script_planner: NpcfScriptPlanner = NpcfScriptPlanner.new()
			script_planner.world = world
			plan = script_planner.plan(goal, view, legal, budget)
			script_planner.world = null
		NpcfPlannerRef.Kind.HOOK:
			if ref.hook != null:
				plan = world.hooks.planner(ref.hook, goal, view, legal, budget)
		_:
			var single: NpcfSingleStepPlanner = NpcfSingleStepPlanner.new()
			single.world = world
			plan = single.plan(goal, view, legal, budget)
			single.world = null
	if plan != null:
		for call: NpcfActionCall in plan.steps:
			call.npc = npc
			call.decision_tick = world.clock.tick
	return plan
