@tool
class_name NpcfRelSeed
extends Resource
## Seeds directed relationship values between two characters when a scenario starts (task 17).

@export var from_character: NpcfCharacterDef = null
@export var to_character: NpcfCharacterDef = null
## Dimension ID -> value.
@export var values: Dictionary[StringName, int] = {}
