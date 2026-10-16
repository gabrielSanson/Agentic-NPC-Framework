@tool
class_name NpcfLocationDef
extends Resource
## A node of the location graph.

@export var id: StringName = &""
@export var tags: Array[StringName] = []
## 0 means unlimited.
@export var capacity: int = 0
## Name of the scene anchor for this location (NpcfLocationAnchor2D); defaults to the ID.
@export var anchor_name: StringName = &""
