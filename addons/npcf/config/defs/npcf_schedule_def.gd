@tool
class_name NpcfScheduleDef
extends Resource
## A daily schedule: time windows that make a goal score through the SCHEDULE input (R10.2).

@export var id: StringName = &""
@export var entries: Array[NpcfScheduleEntry] = []
