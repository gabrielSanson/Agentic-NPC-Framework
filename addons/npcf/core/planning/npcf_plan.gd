class_name NpcfPlan
extends RefCounted
## An ordered list of action calls produced by a planner.

var steps: Array[NpcfActionCall] = []
var planner: StringName = &""


func is_empty() -> bool:
	return steps.is_empty()
