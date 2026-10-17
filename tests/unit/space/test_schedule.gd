extends GdUnitTestSuite
## Schedules: a window is open from its start minus the travel lead to its end; it wraps past midnight;
## and a day filter checks the day of the scheduled start. Uses the toy work day (09:00 to 17:00 at the
## workshop). Ana starts at home_a, 15 ticks (minutes) from the workshop.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(start_minute: int = 480) -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	w.clock.start_minute = start_minute
	return w


func _entry(start: int, end: int, days: Array[int] = []) -> NpcfScheduleEntry:
	var e: NpcfScheduleEntry = NpcfScheduleEntry.new()
	e.start_minute = start
	e.end_minute = end
	e.days = PackedInt32Array(days)
	return e


func test_window_is_open_from_start_to_end() -> void:
	var entry: NpcfScheduleEntry = _entry(540, 1020)
	assert_bool(NpcfScheduleEval.in_window(540, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(800, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(1019, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(1020, entry, 0)).is_false()
	assert_bool(NpcfScheduleEval.in_window(539, entry, 0)).is_false()


func test_window_opens_early_by_exactly_the_travel_lead() -> void:
	var entry: NpcfScheduleEntry = _entry(540, 1020)
	assert_bool(NpcfScheduleEval.in_window(525, entry, 15)).is_true()
	assert_bool(NpcfScheduleEval.in_window(524, entry, 15)).is_false()
	assert_bool(NpcfScheduleEval.in_window(523, entry, 17)).is_true()


func test_active_entry_uses_the_npcs_own_travel_time() -> void:
	var w: NpcfWorld = _world(524)
	var schedule: NpcfScheduleDef = w.pack.schedules[&"toy.work_day"]
	assert_object(NpcfScheduleEval.active_entry(w, &"toy.ana", schedule)).is_null()
	w.clock.start_minute = 525
	var entry: NpcfScheduleEntry = NpcfScheduleEval.active_entry(w, &"toy.ana", schedule)
	assert_object(entry).is_not_null()
	if entry != null:
		assert_str(String(NpcfScheduleEval.entry_location(w, &"toy.home_a", entry))).is_equal("toy.workshop")
	w.clock.start_minute = 1020
	assert_object(NpcfScheduleEval.active_entry(w, &"toy.ana", schedule)).is_null()


func test_window_wraps_past_midnight() -> void:
	var entry: NpcfScheduleEntry = _entry(1380, 60)
	assert_bool(NpcfScheduleEval.in_window(1380, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(1439, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(0, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(59, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(60, entry, 0)).is_false()
	assert_bool(NpcfScheduleEval.in_window(1379, entry, 0)).is_false()


func test_day_filter_checks_the_day_of_the_scheduled_start() -> void:
	var entry: NpcfScheduleEntry = _entry(540, 1020, [1, 2] as Array[int])
	assert_bool(NpcfScheduleEval.in_window(1440 + 600, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(2 * 1440 + 600, entry, 0)).is_true()
	assert_bool(NpcfScheduleEval.in_window(600, entry, 0)).is_false()
	assert_bool(NpcfScheduleEval.in_window(3 * 1440 + 600, entry, 0)).is_false()


func test_day_filter_with_a_lead_uses_the_scheduled_day() -> void:
	# Starts at 09:00 on day 1; the window opens 15 minutes earlier, on day 1 too.
	var entry: NpcfScheduleEntry = _entry(540, 1020, [1] as Array[int])
	assert_bool(NpcfScheduleEval.in_window(1440 + 525, entry, 15)).is_true()
	assert_bool(NpcfScheduleEval.in_window(524, entry, 15)).is_false()


func test_day_filter_on_a_window_that_wraps_past_midnight() -> void:
	# Opens 23:00 on the listed day and runs past midnight. 00:30 of day 1 belongs to day 0's window.
	var entry: NpcfScheduleEntry = _entry(1380, 60, [1] as Array[int])
	assert_bool(NpcfScheduleEval.in_window(1440 + 30, entry, 0)).is_false()
	assert_bool(NpcfScheduleEval.in_window(1440 + 1380, entry, 0)).is_true()
