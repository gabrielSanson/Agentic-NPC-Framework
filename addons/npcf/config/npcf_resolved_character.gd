class_name NpcfResolvedCharacter
extends RefCounted
## A character after the four configuration layers are merged (R4.1). Read-only after resolution.

var id: StringName = &""
var display_name: String = ""
var archetype: StringName = &""
var personalities: Array[StringName] = []
var tags: Array[StringName] = []
var needs: Array[NpcfNeedDef] = []
var need_start: Dictionary[StringName, int] = {}
var goals: Array[NpcfGoalDef] = []
## Products of every layer's multipliers (clamped to 0..3 at scoring time).
var goal_multipliers: Dictionary[StringName, float] = {}
var action_multipliers: Dictionary[StringName, float] = {}
var planner: NpcfPlannerRef = null
var schedule: NpcfScheduleDef = null
var decision_period_ticks: int = 1
var voice: String = ""
var rel_defaults: Dictionary[StringName, int] = {}
var start_location: StringName = &""


func goal_multiplier(goal: StringName) -> float:
	var m: float = goal_multipliers.get(goal, 1.0)
	return clampf(m, 0.0, 3.0)


func action_multiplier(action: StringName) -> float:
	var m: float = action_multipliers.get(action, 1.0)
	return clampf(m, 0.0, 3.0)


func planner_id() -> StringName:
	return planner.planner_id() if planner != null else &"npcf.single_step"


## JSON-friendly dictionary for the `resolve` command and traces.
func to_debug_dict() -> Dictionary:
	var goal_ids: Array[String] = []
	for g: NpcfGoalDef in goals:
		goal_ids.append(String(g.id))
	var need_ids: Array[String] = []
	for n: NpcfNeedDef in needs:
		need_ids.append(String(n.id))
	return {
		"id": String(id), "display_name": display_name, "archetype": String(archetype),
		"personalities": NpcfValueCodec.names(personalities), "tags": NpcfValueCodec.names(tags),
		"needs": need_ids, "need_start": _sorted(need_start), "goals": goal_ids,
		"goal_multipliers": _sorted(goal_multipliers), "action_multipliers": _sorted(action_multipliers),
		"planner": String(planner_id()), "schedule": String(schedule.id) if schedule != null else "",
		"decision_period_ticks": decision_period_ticks, "voice": voice,
		"rel_defaults": _sorted(rel_defaults), "start_location": String(start_location),
	}


func _sorted(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = d.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for k: Variant in keys:
		out[str(k)] = d[k]
	return out
