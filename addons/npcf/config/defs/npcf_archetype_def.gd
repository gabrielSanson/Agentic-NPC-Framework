@tool
class_name NpcfArchetypeDef
extends Resource
## The base layer of the character model: needs, goals, planner, schedule (R4.1).

@export var id: StringName = &""
@export var tags: Array[StringName] = []
@export var needs: Array[NpcfNeedDef] = []
@export var goals: Array[NpcfGoalDef] = []
## Null means `npcf.single_step`.
@export var planner: NpcfPlannerRef = null
@export var schedule: NpcfScheduleDef = null
## NPCs decide every this many ticks unless a trigger marks them due sooner.
@export var decision_period_ticks: int = 1
## Relationship dimension ID -> default value toward others (task 17).
@export var rel_defaults: Dictionary[StringName, int] = {}
