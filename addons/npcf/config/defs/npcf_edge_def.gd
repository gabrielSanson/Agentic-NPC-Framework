@tool
class_name NpcfEdgeDef
extends Resource
## A traversable connection between two locations.

@export var from_location: NpcfLocationDef = null
@export var to_location: NpcfLocationDef = null
## At least 1.
@export var travel_ticks: int = 1
@export var bidirectional: bool = true
