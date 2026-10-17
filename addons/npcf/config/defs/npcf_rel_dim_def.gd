@tool
class_name NpcfRelDimDef
extends Resource
## A directed relationship dimension (R11.1): an integer per (holder, other) pair, clamped to min..max.

@export var id: StringName = &""
@export var min_value: int = -100
@export var max_value: int = 100
@export var default_value: int = 0
## Band name -> inclusive range (x = low, y = high). Bands must not overlap and must lie inside min..max.
@export var bands: Dictionary[StringName, Vector2i] = {}
