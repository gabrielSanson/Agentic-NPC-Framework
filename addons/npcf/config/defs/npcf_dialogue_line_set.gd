@tool
class_name NpcfDialogueLineSet
extends Resource
## Authored lines for one (intent, result, band). An empty band matches any band.

@export var intent: NpcfIntentDef = null
@export var result: StringName = &""
@export var band: StringName = &""
## Placeholders: {npc_name} {location_name} {time_of_day} {result}. Nothing else is allowed (checked at load).
@export var lines: PackedStringArray = []
