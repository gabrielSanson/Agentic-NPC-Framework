class_name NpcfScheduleEval
extends RefCounted
## Reads a daily schedule: which entry is active, where it sends the NPC and whether a window is
## open, counting the travel lead (design "4. Space").
## TODO(task 11): the window, lead and day filter are not implemented yet. The functions return
## the safe defaults (no entry, the entry's own location, not in window).


static func active_entry(_world: NpcfWorld, _npc: StringName, _schedule: NpcfScheduleDef) -> NpcfScheduleEntry:
	return null


static func entry_location(_world: NpcfWorld, _from: StringName, _entry: NpcfScheduleEntry) -> StringName:
	return &""


static func in_window(_total_minutes: int, _entry: NpcfScheduleEntry, _lead_minutes: int) -> bool:
	return false
