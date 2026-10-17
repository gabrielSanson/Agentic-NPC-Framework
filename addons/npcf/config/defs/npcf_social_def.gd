@tool
class_name NpcfSocialDef
extends Resource
## A pack's social mechanisms: relationship dimensions, event-driven deltas, tag transitions, rumor rules.

@export var dims: Array[NpcfRelDimDef] = []
@export var delta_rules: Array[NpcfRelDeltaRule] = []
@export var tag_transitions: Array[NpcfTagTransitionDef] = []
## Null means NpcfRumorRules defaults.
@export var rumors: NpcfRumorRules = null
