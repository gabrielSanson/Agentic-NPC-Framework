class_name NpcfUtilityScorer
extends RefCounted
## Scores goals and actions with compensated utility (design "3. Utility scoring"). A goal's
## utility is U = C * w * M * B: C is the compensated product of its curve outputs, w the goal
## weight, M the NPC's goal multiplier and B = 1 + K * D the directive bias.

## Shared empty args for conditions and subjects. Never mutate it.
static var _NO_ARGS: Dictionary[StringName, Variant] = {}


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


## The raw input of one consideration in 0..1, before its response curve. Reads through `view`, so
## beliefs are used for facts that are not public (read rule, R5.4).
func input(world: NpcfWorld, view: NpcfNpcView, c: NpcfConsiderationDef, goal_id: StringName) -> float:
	var x: float = 0.0
	match c.input:
		NpcfConsiderationDef.InputKind.NEED:
			if c.need != null:
				x = view.need_normalized(c.need.id)
		NpcfConsiderationDef.InputKind.FACT:
			x = _fact_input(world, view, c)
		NpcfConsiderationDef.InputKind.BELIEF_CONFIDENCE:
			if c.fact != null:
				var subject: StringName = NpcfConditions.subject(world, view.npc_id(), c.subject_from, &"", _NO_ARGS)
				x = float(view.fact(subject, c.fact.id).confidence) / 100.0
		NpcfConsiderationDef.InputKind.RELATIONSHIP:
			x = _relationship_input(world, view, c)
		NpcfConsiderationDef.InputKind.TIME_OF_DAY:
			x = float(view.minute_of_day()) / float(NpcfClock.MINUTES_PER_DAY)
		NpcfConsiderationDef.InputKind.SCHEDULE:
			x = _schedule_input(world, view, goal_id)
		NpcfConsiderationDef.InputKind.TRAVEL_TIME:
			x = _travel_input(view, c)
		NpcfConsiderationDef.InputKind.HOOK:
			if c.hook != null:
				x = world.hooks.consideration(c.hook, view, NpcfHookParams.new(c.hook_params))
	return clampf(x, 0.0, 1.0)


## Scores one goal for one NPC: the inputs through their curves, the compensated product, the weight,
## the personality multiplier and the directive bias.
func score(world: NpcfWorld, view: NpcfNpcView, goal: NpcfGoalDef) -> NpcfScoredGoal:
	var s: NpcfScoredGoal = NpcfScoredGoal.new()
	s.goal = goal.id
	var npc_id: StringName = view.npc_id()
	var n: NpcfNpcState = world.npc(npc_id)
	for c: NpcfConsiderationDef in goal.considerations:
		if c == null:
			continue
		var x: float = input(world, view, c, goal.id)
		s.inputs.append(x)
		s.values.append(NpcfCurves.apply(c, x))
	s.compensated = compensate(s.values)
	s.weight = goal.weight
	var multiplier: float = 1.0
	if n != null and n.resolved != null:
		multiplier = n.resolved.goal_multiplier(goal.id)
	s.multiplier = multiplier
	var tags: Array[StringName] = []
	if n != null:
		tags = n.tags
	var priority: float = world.directives.max_priority(npc_id, tags, goal.id)
	s.bias = 1.0 + world.sim.directive_gain * priority
	s.score = s.compensated * s.weight * s.multiplier * s.bias
	return s


## Score of one action for the single-step planner: C(a) * action multiplier / cost.
func score_action(world: NpcfWorld, view: NpcfNpcView, a: NpcfActionDef) -> float:
	var values: Array[float] = []
	for c: NpcfConsiderationDef in a.considerations:
		if c == null:
			continue
		values.append(NpcfCurves.apply(c, input(world, view, c, &"")))
	var n: NpcfNpcState = world.npc(view.npc_id())
	var multiplier: float = 1.0
	if n != null and n.resolved != null:
		multiplier = n.resolved.action_multiplier(a.id)
	if a.cost <= 0.0:
		return 0.0
	return compensate(values) * multiplier / a.cost


func _fact_input(world: NpcfWorld, view: NpcfNpcView, c: NpcfConsiderationDef) -> float:
	if c.fact == null:
		return 0.0
	var subject: StringName = NpcfConditions.subject(world, view.npc_id(), c.subject_from, &"", _NO_ARGS)
	var v: Variant = view.fact_value(subject, c.fact.id)
	match typeof(v):
		TYPE_BOOL:
			var b: bool = v
			return 1.0 if b else 0.0
		TYPE_INT, TYPE_FLOAT:
			var f: float = v
			if c.in_max <= c.in_min:
				return 0.0
			return (f - c.in_min) / (c.in_max - c.in_min)
		TYPE_STRING_NAME:
			var s: StringName = v
			return 1.0 if s != &"" else 0.0
	return 0.0


## Normalized relationship toward the player (subject_from PLAYER), else the highest toward any other NPC at the
## NPC's location. 0.0 when the dimension is unset, there is no player, or the NPC is alone.
func _relationship_input(world: NpcfWorld, view: NpcfNpcView, c: NpcfConsiderationDef) -> float:
	if c.dim == &"":
		return 0.0
	var holder: StringName = view.npc_id()
	if c.subject_from == NpcfConditionDef.SubjectFrom.PLAYER:
		var player: StringName = view.player()
		if player == &"":
			return 0.0
		return world.relationships.normalized(world, holder, player, c.dim)
	var best: float = 0.0
	for other: StringName in world.occupancy.at(view.location()):
		if other == holder:
			continue
		best = maxf(best, world.relationships.normalized(world, holder, other, c.dim))
	return best


## 1.0 while the NPC's active schedule entry names this goal, else 0.0.
func _schedule_input(world: NpcfWorld, view: NpcfNpcView, goal_id: StringName) -> float:
	var n: NpcfNpcState = world.npc(view.npc_id())
	if n == null or n.resolved == null:
		return 0.0
	var entry: NpcfScheduleEntry = NpcfScheduleEval.active_entry(world, view.npc_id(), n.resolved.schedule)
	if entry != null and entry.goal != null and entry.goal.id == goal_id:
		return 1.0
	return 0.0


## Travel ticks from the NPC's location to the nearest location with the tag, divided by in_max.
## 1.0 when no such location is reachable.
func _travel_input(view: NpcfNpcView, c: NpcfConsiderationDef) -> float:
	var here: StringName = view.location()
	var dest: StringName = view.nearest_with_tag(here, c.location_tag)
	if dest == &"":
		return 1.0
	var ticks: int = view.travel_ticks(here, dest)
	if ticks < 0:
		return 1.0
	if c.in_max <= 0.0:
		return 0.0
	return float(ticks) / c.in_max
