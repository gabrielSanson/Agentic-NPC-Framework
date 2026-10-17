class_name NpcfScheduleEval
extends RefCounted
## Reads a daily schedule: which entry is active, where it sends the NPC and whether a window is open,
## counting the travel lead (design "4. Space"). A window opens early by the travel time from the NPC's
## current location, so the NPC arrives on time. Static helpers only.


## The first entry whose window (with its travel lead) is open now, or null.
static func active_entry(world: NpcfWorld, npc: StringName, schedule: NpcfScheduleDef) -> NpcfScheduleEntry:
	if schedule == null:
		return null
	var total: int = world.clock.total_minutes()
	var here: StringName = world.location_of(npc)
	for entry: NpcfScheduleEntry in schedule.entries:
		if entry == null:
			continue
		var lead: int = _lead_minutes(world, here, entry)
		if in_window(total, entry, lead):
			return entry
	return null


## Where an entry sends the NPC: its location, or for a tag the nearest such location from `from`.
static func entry_location(world: NpcfWorld, from: StringName, entry: NpcfScheduleEntry) -> StringName:
	if entry == null:
		return &""
	if entry.location != null:
		return entry.location.id
	if entry.location_tag != &"":
		return world.pack.location_index.nearest_with_tag(from, entry.location_tag)
	return &""


## True while the entry's window is open. The window opens `lead_minutes` before its start time and
## runs to its end time. Day filter: the scheduled start must fall on a listed day of the week.
static func in_window(total_minutes: int, entry: NpcfScheduleEntry, lead_minutes: int) -> bool:
	var day_minutes: int = NpcfClock.MINUTES_PER_DAY
	var length: int = posmod(entry.end_minute - entry.start_minute, day_minutes)
	var opens: int = entry.start_minute - lead_minutes
	var d: int = posmod(total_minutes - opens, day_minutes)
	if d >= length + lead_minutes:
		return false
	if entry.days.is_empty():
		return true
	var scheduled_start: int = total_minutes - d + lead_minutes
	var day_index: int = floori(float(scheduled_start) / float(day_minutes))
	return entry.days.has(posmod(day_index, 7))


## Minutes of travel from `here` to the entry's location; 0 when unreachable or already there.
static func _lead_minutes(world: NpcfWorld, here: StringName, entry: NpcfScheduleEntry) -> int:
	var dest: StringName = entry_location(world, here, entry)
	var ticks: int = world.pack.location_index.travel_ticks(here, dest)
	if ticks <= 0:
		return 0
	return ticks * world.clock.minutes_per_tick
