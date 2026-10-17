extends GdUnitTestSuite
## The toy day: for seeds 1 to 5, 1,440 ticks of toy.basic (one day from 08:00). No invariant may fail.
## Every NPC completes toy.work at the workshop at some minute between 540 and 1020, and completes
## toy.rest at a home location. Outcomes are read from the tick reports, so the trace ring buffer size
## does not matter.

const SEEDS: Array[int] = [1, 2, 3, 4, 5]
const TICKS: int = 1440
const WORK_FROM: int = 540
const WORK_UNTIL: int = 1020


func _run(world_seed: int) -> Dictionary:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), world_seed)
	var failures: Array[String] = []
	var work: Dictionary[StringName, Array] = {}
	var rest: Dictionary[StringName, Array] = {}
	for id: StringName in w.npc_ids:
		work[id] = []
		rest[id] = []
	for _i: int in TICKS:
		var report: NpcfTickReport = w.step()
		for f: NpcfInvariantFailure in report.invariant_failures:
			failures.append(f.format())
		for o: NpcfActionOutcome in report.finished:
			if o.outcome != &"success":
				continue
			var minute: int = _minute_of_day(w, o.tick)
			if o.action == &"toy.work":
				work[o.npc].append({"minute": minute, "location": o.location})
			elif o.action == &"toy.rest":
				rest[o.npc].append({"minute": minute, "location": o.location})
	var result: Dictionary = {"failures": failures, "work": work, "rest": rest, "world": w}
	return result


func _minute_of_day(w: NpcfWorld, tick: int) -> int:
	var total: int = w.clock.start_day * NpcfClock.MINUTES_PER_DAY + w.clock.start_minute + tick * w.clock.minutes_per_tick
	return total % NpcfClock.MINUTES_PER_DAY


func test_toy_day_holds_for_seeds_one_to_five() -> void:
	for world_seed: int in SEEDS:
		var r: Dictionary = _run(world_seed)
		var w: NpcfWorld = r["world"]
		var failures: Array[String] = r["failures"]
		var work: Dictionary = r["work"]
		var rest: Dictionary = r["rest"]
		assert_array(failures).override_failure_message("seed %d: invariant failures" % world_seed).is_empty()
		for id: StringName in w.npc_ids:
			var work_outcomes: Array = work[id]
			var rest_outcomes: Array = rest[id]
			_assert_work(world_seed, w, id, work_outcomes)
			_assert_rest(world_seed, w, id, rest_outcomes)
		w.dispose()


func _assert_work(world_seed: int, w: NpcfWorld, id: StringName, outcomes: Array) -> void:
	var ok: bool = false
	for o: Dictionary in outcomes:
		var minute: int = o["minute"]
		var location: StringName = o["location"]
		if minute >= WORK_FROM and minute <= WORK_UNTIL and location == &"toy.workshop":
			ok = true
	assert_bool(ok).override_failure_message("seed %d: %s has no toy.work success at toy.workshop between %d and %d (%s)"
			% [world_seed, id, WORK_FROM, WORK_UNTIL, str(outcomes.map(func(x: Dictionary) -> int: return x["minute"]))]).is_true()


func _assert_rest(world_seed: int, w: NpcfWorld, id: StringName, outcomes: Array) -> void:
	var ok: bool = false
	for o: Dictionary in outcomes:
		var location: StringName = o["location"]
		if w.pack.location_index.has_tag(location, &"toy.home"):
			ok = true
	assert_bool(ok).override_failure_message("seed %d: %s has no toy.rest success at a home location" % [world_seed, id]).is_true()
