@tool
class_name NpcfDirectorRuleDef
extends Resource
## A Director rule: when its conditions hold on a cadence tick, it emits a tag-targeted directive for a goal.

@export var id: StringName = &""
## Checked on ticks where tick % cadence_ticks == 0.
@export var cadence_ticks: int = 60
## All must hold.
@export var conditions: Array[NpcfMacroCondition] = []
@export var target: NpcfTagQuery = null
@export var goal: NpcfGoalDef = null
@export_range(0.0, 1.0) var priority: float = 0.5
@export var duration_ticks: int = 60
