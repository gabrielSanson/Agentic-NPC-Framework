class_name NpcfRejectedGoal
extends RefCounted
## A goal that was not chosen for a reason other than its score (cooldown, no plan ...).

var goal: StringName = &""
var reason: StringName = &""


static func make(p_goal: StringName, p_reason: StringName) -> NpcfRejectedGoal:
	var r: NpcfRejectedGoal = NpcfRejectedGoal.new()
	r.goal = p_goal
	r.reason = p_reason
	return r
