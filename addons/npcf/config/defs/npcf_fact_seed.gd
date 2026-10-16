@tool
class_name NpcfFactSeed
extends Resource
## Sets one fact for one subject when a scenario starts.

@export var fact: NpcfFactDef = null
## Entity or location ID; leave empty for a global fact.
@export var subject: StringName = &""
@export var value: Variant = null
