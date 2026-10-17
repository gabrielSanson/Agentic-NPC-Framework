class_name NpcfTraceService
extends RefCounted
## Explains one NPC (R17.1, R17.2). Read-only: never changes the world.

const DIALOGUE_RECORDS: int = 10


## The trace of one NPC as JSON-safe values, or {} when `npc` is not an NPC.
static func trace(world: NpcfWorld, npc: StringName) -> Dictionary:
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return {}
	var out: Dictionary = {}
	out["npc"] = String(npc)
	out["tick"] = world.clock.tick
	out["time"] = world.clock.label()
	out["config"] = _config(n)
	out["needs"] = _needs(n)
	out["location"] = String(world.location_of(npc))
	out["tags"] = NpcfValueCodec.names(n.tags)
	out["goal"] = String(n.current_goal)
	var action: String = String(n.running.call.action) if n.is_busy() else ""
	out["action"] = action
	out["running"] = action
	out["action_elapsed"] = n.running.elapsed if n.is_busy() else 0
	out["plan"] = _plan(n)
	out["beliefs"] = _beliefs(n)
	out["directives"] = _directives(world, npc, n)
	out["decisions"] = _decisions(n)
	out["outcomes"] = _outcomes(n)
	out["dialogue"] = _dialogue(world, npc)
	out["hook_failures"] = _hook_failures(world)
	return out


static func _config(n: NpcfNpcState) -> Dictionary:
	var r: NpcfResolvedCharacter = n.resolved
	if r == null:
		return {}
	var goals: Array = []
	for g: NpcfGoalDef in r.goals:
		if g != null:
			goals.append(String(g.id))
	var planner_path: String = ""
	if r.planner != null and r.planner.hook != null:
		planner_path = r.planner.hook.resource_path
	var schedule_id: String = String(r.schedule.id) if r.schedule != null else ""
	return {
		"display_name": r.display_name, "archetype": String(r.archetype),
		"personalities": NpcfValueCodec.names(r.personalities),
		"decision_period_ticks": r.decision_period_ticks, "goals": goals,
		"planner": planner_path, "schedule": schedule_id,
	}


## Needs in sorted ID order.
static func _needs(n: NpcfNpcState) -> Dictionary:
	var ids: Array[StringName] = []
	for id: StringName in n.needs:
		ids.append(id)
	ids.sort_custom(NpcfWorldState.name_less)
	var out: Dictionary = {}
	for id: StringName in ids:
		out[String(id)] = n.needs[id]
	return out


static func _plan(n: NpcfNpcState) -> Array:
	var out: Array = []
	for step: NpcfActionCall in n.plan:
		out.append(String(step.action))
	return out


static func _beliefs(n: NpcfNpcState) -> Array:
	var out: Array = []
	for b: NpcfBelief in n.beliefs.all():
		out.append(b.to_dict())
	return out


static func _directives(world: NpcfWorld, npc: StringName, n: NpcfNpcState) -> Array:
	var out: Array = []
	for d: NpcfDirective in world.directives.active():
		if d.targets(npc, n.tags):
			out.append(d.to_dict())
	return out


static func _decisions(n: NpcfNpcState) -> Array:
	var out: Array = []
	for r: NpcfDecisionRecord in n.decision_records:
		out.append(r.to_dict())
	return out


static func _outcomes(n: NpcfNpcState) -> Array:
	var out: Array = []
	for o: NpcfActionOutcome in n.action_outcomes:
		out.append(o.to_dict())
	return out


## The last turn records of this NPC, oldest first.
static func _dialogue(world: NpcfWorld, npc: StringName) -> Array:
	var mine: Array = []
	if world.dialogue == null:
		return mine
	for r: NpcfDialogueTurnRecord in world.dialogue.records:
		if r.npc == npc:
			mine.append(r.to_dict())
	var start: int = maxi(0, mine.size() - DIALOGUE_RECORDS)
	return mine.slice(start)


## Hook failure counters by hook script path, plus the total. The counter has no NPC key, so every failure is listed.
static func _hook_failures(world: NpcfWorld) -> Dictionary:
	var out: Dictionary = {}
	var total: int = 0
	var keys: Array[String] = []
	for key: String in world.hooks.failures:
		keys.append(key)
	keys.sort()
	for key: String in keys:
		var count: int = world.hooks.failures[key]
		out[key] = count
		total += count
	out["total"] = total
	return out
