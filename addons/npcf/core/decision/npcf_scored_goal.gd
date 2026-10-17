class_name NpcfScoredGoal
extends RefCounted
## One goal's utility breakdown: the inputs, their compensated product and the bias terms.

var goal: StringName = &""
var inputs: Array[float] = []
var values: Array[float] = []
## C: the compensated product of the values.
var compensated: float = 0.0
var weight: float = 1.0
var multiplier: float = 1.0
## B = 1 + K * D, where D is the strongest directive priority.
var bias: float = 1.0
## U = C * w * M * B.
var score: float = 0.0


func to_dict() -> Dictionary:
	return {
		"goal": String(goal), "inputs": inputs, "values": values, "compensated": compensated,
		"weight": weight, "multiplier": multiplier, "bias": bias, "score": score,
	}
