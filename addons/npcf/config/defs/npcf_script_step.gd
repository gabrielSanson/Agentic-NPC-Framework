@tool
class_name NpcfScriptStep
extends Resource
## One step of an authored plan: an action and literal arguments.

@export var action: NpcfActionDef = null
@export var args: Dictionary[StringName, Variant] = {}
