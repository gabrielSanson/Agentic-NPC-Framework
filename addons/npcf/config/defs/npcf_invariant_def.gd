@tool
class_name NpcfInvariantDef
extends Resource
## A pack-declared state check, run after ticks in headless runs and periodically in game.

@export var id: StringName = &""
## Script extending NpcfInvariantHook.
@export var hook: Script = null
