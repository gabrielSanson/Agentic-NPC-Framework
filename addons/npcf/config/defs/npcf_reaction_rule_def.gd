@tool
class_name NpcfReactionRuleDef
extends Resource
## Reacts to a delivered event with a personal directive and an immediate decision (R8.3).

@export var id: StringName = &""
@export var event_kind: NpcfEventKindDef = null
## When true, only participants and witnesses react (not broadcast or told).
@export var witnessed_only: bool = true
## Evaluated on the receiver's view; null means always.
@export var condition: NpcfConditionDef = null
@export var goal: NpcfGoalDef = null
@export_range(0.0, 1.0) var priority: float = 0.5
@export var duration_ticks: int = 30
## Per NPC per rule.
@export var cooldown_ticks: int = 60
