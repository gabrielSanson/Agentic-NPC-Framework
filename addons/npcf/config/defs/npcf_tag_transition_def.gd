@tool
class_name NpcfTagTransitionDef
extends Resource
## Changes an NPC's tags when its condition holds (R11.2), checked every tick in phase 4.

@export var id: StringName = &""
## All of these tags must be present for the transition to be checked.
@export var requires_tags: Array[StringName] = []
## Evaluated on the NPC's own view. Null means always true.
@export var condition: NpcfConditionDef = null
@export var add: Array[StringName] = []
@export var remove: Array[StringName] = []
