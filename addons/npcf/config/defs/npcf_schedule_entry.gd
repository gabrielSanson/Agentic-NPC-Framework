@tool
class_name NpcfScheduleEntry
extends Resource
## One schedule window. The window opens early by the NPC's travel time to the location.

## Day-of-week indexes 0..6 (day_of_week = day % 7); empty means every day.
@export var days: PackedInt32Array = PackedInt32Array()
@export_range(0, 1440) var start_minute: int = 540
## An end before the start wraps past midnight.
@export_range(0, 1440) var end_minute: int = 1020
@export var goal: NpcfGoalDef = null
## Exactly one of location and location_tag.
@export var location: NpcfLocationDef = null
@export var location_tag: StringName = &""
