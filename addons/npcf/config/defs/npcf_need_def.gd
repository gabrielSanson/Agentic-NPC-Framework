@tool
class_name NpcfNeedDef
extends Resource
## An integer meter per NPC that changes every tick (hunger, energy ...).

@export var id: StringName = &""
@export var min_value: int = 0
@export var max_value: int = 1000
## Starting value; characters and cast entries can override it.
@export var start: int = 500
## Change applied every tick (negative drains the meter).
@export var change_per_tick: int = 0
## Named thresholds. Crossing one in either direction emits `npcf.need_threshold` and marks a
## decision due.
@export var thresholds: Dictionary[StringName, int] = {}
