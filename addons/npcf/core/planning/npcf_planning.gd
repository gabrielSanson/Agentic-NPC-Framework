class_name NpcfPlanning
extends RefCounted
## Turns a goal into a plan through the planner the NPC uses (design "3. Planning"). Legal actions are
## computed from the NPC's own view; every call of the plan is stamped with the decision tick.


## The plan for one goal, or null when the NPC's planner finds none.
static func plan_for(world: NpcfWorld, npc: StringName, goal: NpcfGoalDef) -> NpcfPlan:
	return Session.new(world, npc).plan_for(goal)


## The objects one decision shares across its goals: the NPC's view, a budget and one planner of each
## kind. The view and the planners keep no state between goals (a planner's world is set per call), so
## only the budget is reset for each goal.
class Session extends RefCounted:
	var _world: NpcfWorld
	var _npc: StringName
	var _view: NpcfNpcView
	var _budget: NpcfPlanBudget = NpcfPlanBudget.new()
	var _single: NpcfSingleStepPlanner = NpcfSingleStepPlanner.new()
	var _script: NpcfScriptPlanner = NpcfScriptPlanner.new()

	func _init(world: NpcfWorld, npc: StringName) -> void:
		_world = world
		_npc = npc
		_view = world.view(npc)

	## The plan for one goal, or null when the NPC's planner finds none.
	func plan_for(goal: NpcfGoalDef) -> NpcfPlan:
		var n: NpcfNpcState = _world.npc(_npc)
		if n == null or n.resolved == null or goal == null:
			return null
		var candidates: Array[NpcfActionDef] = []
		var seen: Dictionary[NpcfActionDef, bool] = {}
		for a: NpcfActionDef in goal.candidate_actions:
			if a != null and not seen.has(a):
				seen[a] = true
				candidates.append(a)
		if goal.script_steps != null:
			for step: NpcfScriptStep in goal.script_steps.steps:
				if step != null and step.action != null and not seen.has(step.action):
					seen[step.action] = true
					candidates.append(step.action)
		var legal: NpcfLegalActions = _world.action_registry.legal_for(_world, _view, candidates)
		_budget.max_steps = NpcfPlanBudget.DEFAULT_MAX_STEPS
		var ref: NpcfPlannerRef = n.resolved.planner
		var kind: NpcfPlannerRef.Kind = ref.kind if ref != null else NpcfPlannerRef.Kind.SINGLE_STEP
		var plan: NpcfPlan = null
		match kind:
			NpcfPlannerRef.Kind.SCRIPT:
				_script.world = _world
				plan = _script.plan(goal, _view, legal, _budget)
				_script.world = null
			NpcfPlannerRef.Kind.HOOK:
				if ref.hook != null:
					plan = _world.hooks.planner(ref.hook, goal, _view, legal, _budget)
			_:
				_single.world = _world
				plan = _single.plan(goal, _view, legal, _budget)
				_single.world = null
		if plan != null:
			for call: NpcfActionCall in plan.steps:
				call.npc = _npc
				call.decision_tick = _world.clock.tick
		return plan
