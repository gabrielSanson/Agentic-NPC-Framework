class_name NpcfRuleOutcome
extends RefCounted
## The rule-decided result of a dialogue turn (task 19).

var result: StringName = &""
var changes: Array[NpcfStateChange] = []
var revealed: Array[NpcfFactRef] = []
var line_key: StringName = &""


static func none() -> NpcfRuleOutcome:
	var o: NpcfRuleOutcome = NpcfRuleOutcome.new()
	o.result = &"none"
	return o
