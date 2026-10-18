extends GdUnitTestSuite
## The decision scheduler: periodic phases spread over the period and are the same for the same seed,
## triggered entries are capped and taken in (due tick, ID) order, busy NPCs are not marked periodic,
## a capped tick takes bypass requests first, and a bypass request supplies the reason of the taken entry.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## The toy world with five villagers: Ana, Bo, Cy (basic cast) and Dee and Eli at home_b.
func _five(world_seed: int) -> NpcfWorld:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var scenario: NpcfScenarioDef = ToyFixture.basic()
	var villager: NpcfArchetypeDef = pack.archetypes[&"toy.villager"]
	for id: StringName in [&"toy.dee", &"toy.eli"]:
		var c: NpcfCharacterDef = NpcfCharacterDef.new()
		c.id = id
		c.display_name = String(id)
		c.archetype = villager
		var entry: NpcfCastEntry = NpcfCastEntry.new()
		entry.character = c
		entry.start_location = pack.location(&"toy.home_b")
		scenario.cast.append(entry)
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, scenario, world_seed)
	_worlds.append(w)
	return w


## Advances the clock one tick and returns the NPCs taken that tick.
func _take(w: NpcfWorld, cap: int) -> Array[StringName]:
	w.clock.advance()
	return w.scheduler.take_due(w, cap)


func _periodic_ticks(w: NpcfWorld) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for id: StringName in w.npc_ids:
		out[id] = w.npc(id).next_periodic_tick
	return out


func test_periodic_decisions_spread_over_the_period() -> void:
	var w: NpcfWorld = _five(7)
	var per_tick: Dictionary[int, int] = {}
	var counts: Dictionary[StringName, int] = {}
	for _i: int in 5:
		var taken: Array[StringName] = _take(w, 100)
		per_tick[w.clock.tick] = taken.size()
		for id: StringName in taken:
			counts[id] = counts.get(id, 0) + 1
	# Five villagers with period 5: each decides exactly once in the first five ticks.
	assert_int(counts.size()).is_equal(5)
	for id: StringName in w.npc_ids:
		assert_int(counts.get(id, 0)).is_equal(1)
	assert_bool(per_tick.values().has(5)).is_false()


func test_phases_are_the_same_for_the_same_seed() -> void:
	var a: NpcfWorld = _five(7)
	var b: NpcfWorld = _five(7)
	assert_dict(_periodic_ticks(a)).is_equal(_periodic_ticks(b))


func test_each_npc_is_due_once_per_period_after_its_phase() -> void:
	var w: NpcfWorld = _five(7)
	var seen: Dictionary[StringName, int] = {}
	for _i: int in 15:
		for id: StringName in _take(w, 100):
			seen[id] = seen.get(id, 0) + 1
	for id: StringName in w.npc_ids:
		assert_int(seen.get(id, 0)).is_equal(3)


func test_cap_of_two_decides_all_five_within_three_ticks_in_id_order() -> void:
	var w: NpcfWorld = _five(7)
	for id: StringName in w.npc_ids:
		w.npc(id).next_periodic_tick = 1000
	for id: StringName in [&"toy.eli", &"toy.cy", &"toy.ana", &"toy.dee", &"toy.bo"]:
		w.scheduler.mark_due(w, id, &"test", false)
	var first: Array[StringName] = _take(w, 2)
	var second: Array[StringName] = _take(w, 2)
	var third: Array[StringName] = _take(w, 2)
	assert_array(first).is_equal([&"toy.ana", &"toy.bo"])
	assert_array(second).is_equal([&"toy.cy", &"toy.dee"])
	assert_array(third).is_equal([&"toy.eli"])
	assert_array(_take(w, 2)).is_empty()


func test_earlier_due_ticks_are_taken_before_later_ones() -> void:
	var w: NpcfWorld = _five(7)
	for id: StringName in w.npc_ids:
		w.npc(id).next_periodic_tick = 1000
	w.scheduler.mark_due(w, &"toy.cy", &"test", false)
	_take(w, 0)
	w.scheduler.mark_due(w, &"toy.ana", &"test", false)
	assert_array(_take(w, 1)).is_equal([&"toy.cy"])
	assert_array(_take(w, 1)).is_equal([&"toy.ana"])


func test_a_capped_tick_takes_bypass_requests_first() -> void:
	var w: NpcfWorld = _five(7)
	for id: StringName in w.npc_ids:
		w.npc(id).next_periodic_tick = 1000
	w.scheduler.mark_due(w, &"toy.ana", &"test", false)
	w.scheduler.mark_due(w, &"toy.bo", &"test", false)
	_take(w, 0)
	w.scheduler.mark_due(w, &"toy.eli", &"reaction", true, &"x.rule")
	w.scheduler.mark_due(w, &"toy.cy", &"test", false)
	# Eli's reaction jumps the earlier waiting entries; the rest keep (due tick, ID) order.
	assert_array(_take(w, 2)).is_equal([&"toy.eli", &"toy.ana"])
	assert_array(_take(w, 2)).is_equal([&"toy.bo", &"toy.cy"])


func test_an_uncapped_tick_keeps_due_tick_and_id_order() -> void:
	var w: NpcfWorld = _five(7)
	for id: StringName in w.npc_ids:
		w.npc(id).next_periodic_tick = 1000
	w.scheduler.mark_due(w, &"toy.ana", &"test", false)
	_take(w, 0)
	w.scheduler.mark_due(w, &"toy.eli", &"reaction", true, &"x.rule")
	w.scheduler.mark_due(w, &"toy.bo", &"test", false)
	assert_array(_take(w, 3)).is_equal([&"toy.ana", &"toy.bo", &"toy.eli"])


func test_busy_npcs_are_not_marked_periodic() -> void:
	var w: NpcfWorld = _five(7)
	var report: NpcfTickReport = NpcfTickReport.new()
	var rest: NpcfActionCall = NpcfActionCall.make(&"toy.ana", &"toy.rest", {} as Dictionary[StringName, Variant], 0)
	assert_str(String(w.executor.start(w, &"toy.ana", rest, report))).is_equal("ok")
	w.npc(&"toy.ana").next_periodic_tick = 1
	w.npc(&"toy.bo").next_periodic_tick = 1
	var ana_taken: int = 0
	var bo_taken: int = 0
	for _i: int in 10:
		for id: StringName in _take(w, 100):
			if id == &"toy.ana":
				ana_taken += 1
			if id == &"toy.bo":
				bo_taken += 1
	assert_int(ana_taken).is_equal(0)
	# Bo is free and has period 5: due at ticks 1 and 6.
	assert_int(bo_taken).is_equal(2)
	# Ana's periodic schedule moved on while busy, so she is due again once she is free.
	assert_int(w.npc(&"toy.ana").next_periodic_tick).is_greater(10)


func test_earliest_due_tick_wins_and_a_bypass_supplies_the_reason() -> void:
	var w: NpcfWorld = _five(7)
	for id: StringName in w.npc_ids:
		w.npc(id).next_periodic_tick = 1000
	w.scheduler.mark_due(w, &"toy.ana", &"first", false)
	w.scheduler.mark_due(w, &"toy.ana", &"reaction", true, &"x.rule")
	w.scheduler.mark_due(w, &"toy.ana", &"later", false)
	assert_array(_take(w, 5)).is_equal([&"toy.ana"])
	var entry: NpcfDueEntry = w.scheduler.last_taken(&"toy.ana")
	assert_bool(entry.bypass).is_true()
	assert_str(String(entry.reason)).is_equal("reaction")
	assert_str(String(entry.rule)).is_equal("x.rule")
