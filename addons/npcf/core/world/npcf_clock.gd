class_name NpcfClock
extends RefCounted
## Fixed-step clock: ticks to game day and minute of day (R1.1).

const MINUTES_PER_DAY: int = 1440

var tick: int = 0
var minutes_per_tick: int = 1
var start_day: int = 0
var start_minute: int = 0


func _init(p_minutes_per_tick: int = 1, p_start_day: int = 0, p_start_minute: int = 0) -> void:
	minutes_per_tick = maxi(1, p_minutes_per_tick)
	start_day = p_start_day
	start_minute = p_start_minute


func advance() -> void:
	tick += 1


## Game minutes since day 0, 00:00.
func total_minutes() -> int:
	return start_day * MINUTES_PER_DAY + start_minute + tick * minutes_per_tick


func day() -> int:
	return total_minutes() / MINUTES_PER_DAY


func minute_of_day() -> int:
	return total_minutes() % MINUTES_PER_DAY


## Day of the week 0..6, as used by schedule day filters.
func day_of_week() -> int:
	return day() % 7


## "d2 08:15", for logs.
func label() -> String:
	return "d%d %02d:%02d" % [day(), minute_of_day() / 60, minute_of_day() % 60]
