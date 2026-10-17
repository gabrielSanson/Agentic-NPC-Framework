extends GdUnitTestSuite
## Needs: per-tick decay, bounds, threshold crossings in each direction, and running action deltas.
## Uses the real toy pack (energy drains 1 per tick and has a `toy.tired` threshold at 200).

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _ticks(w: NpcfWorld, n: int) -> void:
	for _i: int in n:
		w.need_system.tick(w)


## Directions of Ana's threshold events (the other NPCs have their own crossings).
func _threshold_directions(w: NpcfWorld) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: NpcfEvent in w.events.log:
		if e.kind == NpcfFramework.NEED_THRESHOLD and e.actors == [&"toy.ana"]:
			var d: StringName = e.payload[&"direction"]
			out.append(d)
	return out


func test_needs_change_by_their_per_tick_rate() -> void:
	var w: NpcfWorld = _world()
	_ticks(w, 1)
	assert_int(w.npc(&"toy.ana").needs[&"toy.energy"]).is_equal(699)
	assert_int(w.npc(&"toy.ana").needs[&"toy.curiosity"]).is_equal(501)


func test_needs_clamp_at_their_bounds() -> void:
	var w: NpcfWorld = _world()
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", 2, true)
	_ticks(w, 5)
	assert_int(w.npc(&"toy.ana").needs[&"toy.energy"]).is_equal(0)
	w.need_system.set_need(w, &"toy.ana", &"toy.curiosity", 999, true)
	_ticks(w, 5)
	assert_int(w.npc(&"toy.ana").needs[&"toy.curiosity"]).is_equal(1000)


func test_set_need_clamps_to_bounds() -> void:
	var w: NpcfWorld = _world()
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", 5000, true)
	assert_int(w.npc(&"toy.ana").needs[&"toy.energy"]).is_equal(1000)
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", -20, true)
	assert_int(w.npc(&"toy.ana").needs[&"toy.energy"]).is_equal(0)


func test_threshold_fires_once_per_downward_crossing() -> void:
	var w: NpcfWorld = _world()
	_ticks(w, 510)  # 700 -> 190, crossing 200 once
	assert_array(_threshold_directions(w)).is_equal([&"down"])
	_ticks(w, 50)  # stays below the threshold: no new event
	assert_array(_threshold_directions(w)).is_equal([&"down"])


func test_threshold_fires_on_upward_crossing_and_again_on_the_next_fall() -> void:
	var w: NpcfWorld = _world()
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", 150, true)
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", 300)
	assert_array(_threshold_directions(w)).is_equal([&"up"])
	_ticks(w, 200)  # 300 -> 100 crosses 200 downward once more
	assert_array(_threshold_directions(w)).is_equal([&"up", &"down"])


func test_threshold_event_names_need_threshold_and_direction() -> void:
	var w: NpcfWorld = _world()
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", 210, true)
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", 199)
	var found: NpcfEvent = null
	for e: NpcfEvent in w.events.log:
		if e.kind == NpcfFramework.NEED_THRESHOLD and e.actors == [&"toy.ana"]:
			found = e
	assert_object(found).is_not_null()
	if found != null:
		var need: StringName = found.payload[&"need"]
		var threshold: StringName = found.payload[&"threshold"]
		assert_str(String(need)).is_equal("toy.energy")
		assert_str(String(threshold)).is_equal("toy.tired")
		assert_array(found.actors).is_equal([&"toy.ana"])


func test_quiet_set_need_emits_no_threshold() -> void:
	var w: NpcfWorld = _world()
	w.need_system.set_need(w, &"toy.ana", &"toy.energy", 100, true)
	assert_array(_threshold_directions(w)).is_empty()


func test_running_action_adds_its_per_tick_delta() -> void:
	var w: NpcfWorld = _world()
	var npc: NpcfNpcState = w.npc(&"toy.ana")
	var ra: NpcfRunningAction = NpcfRunningAction.new()
	ra.def = w.pack.action(&"toy.rest")
	ra.call = NpcfActionCall.make(&"toy.ana", &"toy.rest", {} as Dictionary[StringName, Variant], 0)
	npc.running = ra
	_ticks(w, 1)
	assert_int(npc.needs[&"toy.energy"]).is_equal(705)  # -1 drain plus +6 from rest


func test_finished_action_adds_no_delta() -> void:
	var w: NpcfWorld = _world()
	var npc: NpcfNpcState = w.npc(&"toy.ana")
	var ra: NpcfRunningAction = NpcfRunningAction.new()
	ra.def = w.pack.action(&"toy.rest")
	ra.call = NpcfActionCall.make(&"toy.ana", &"toy.rest", {} as Dictionary[StringName, Variant], 0)
	ra.finished = true
	npc.running = ra
	_ticks(w, 1)
	assert_int(npc.needs[&"toy.energy"]).is_equal(699)
