@tool
class_name NpcfCastEntry
extends Resource
## Places a character in a scenario, with scenario-specific overrides (the last layer).

@export var character: NpcfCharacterDef = null
@export var start_location: NpcfLocationDef = null
## Null inherits the character's schedule.
@export var schedule: NpcfScheduleDef = null
@export var need_start: Dictionary[StringName, int] = {}
@export var tags_add: Array[StringName] = []
