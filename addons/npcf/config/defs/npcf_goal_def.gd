@tool
class_name NpcfGoalDef
extends Resource
## A goal NPCs score with utility and pursue through a planner.

@export var id: StringName = &""
@export_range(0.0, 10.0) var weight: float = 1.0
## Another goal must beat this one by this fraction to replace it.
@export_range(0.0, 1.0) var hysteresis: float = 0.1
@export var considerations: Array[NpcfConsiderationDef] = []
## When this holds for an NPC, switching to the goal bypasses hysteresis.
@export var interrupt: NpcfConditionDef = null
## Actions the single-step planner may choose from.
@export var candidate_actions: Array[NpcfActionDef] = []
## Authored steps for the script planner.
@export var script_steps: NpcfScriptDef = null
## Ticks the goal is skipped after a planning or movement failure.
@export var unreachable_cooldown_ticks: int = 30
