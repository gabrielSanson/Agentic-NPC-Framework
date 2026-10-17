@tool
class_name NpcfMacroVarDef
extends Resource
## A world-level number the Director tracks (R12.1).

@export var id: StringName = &""
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var start: float = 0.0
@export var deltas: Array[NpcfMacroDelta] = []
