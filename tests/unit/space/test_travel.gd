extends GdUnitTestSuite
## Travel: a two-edge path (5 + 10 ticks) arrives on start + 15; departed and arrived events land at the
## right places and ticks; npcf.at changes only on edge completion; an embodied mover hands its path to
## the movement adapter and, when disembodied, resumes with a fresh edge timer; the player arrives via an
## ARRIVED input. Ticks run through the executor and delivery directly, so no decisions interfere.


class FakeMovement extends NpcfMovementAdapter:
	var embodied: bool = false
	var walks: Array[Array] = []

	func is_embodied(_npc: StringName) -> bool:
		return embodied

	func move_along(_npc: StringName, _call_id: int, path: Array[StringName]) -> void:
		walks.append(path.duplicate())


var _worlds: Array[NpcfWorld] = []
var _report: NpcfTickReport = null


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	_report = NpcfTickReport.new()
	return w


func _move(w: NpcfWorld, npc: StringName, to: StringName) -> void:
	var args: Dictionary[StringName, Variant] = {&"location": to}
	var call: NpcfActionCall = NpcfActionCall.make(npc, NpcfFramework.MOVE_TO, args, w.clock.tick)
	assert_str(String(w.executor.start(w, npc, call, _report))).is_equal("ok")


## One tick of the actions phase, without decisions: clock, executor, delivery.
func _tick(w: NpcfWorld, n: int = 1) -> void:
	for _i: int in n:
		w.clock.advance()
		w.executor.advance(w, _report)
		w.delivery.deliver_pending(w)


func _last_outcome(w: NpcfWorld, npc: StringName) -> String:
	var list: Array[NpcfActionOutcome] = w.npc(npc).action_outcomes
	var last: StringName = list.back().outcome
	return String(last)


func _events(w: NpcfWorld, kind: StringName) -> Array[NpcfEvent]:
	var out: Array[NpcfEvent] = []
	for e: NpcfEvent in w.events.log:
		if e.kind == kind:
			out.append(e)
	return out


func test_two_edge_path_arrives_on_start_plus_fifteen() -> void:
	var w: NpcfWorld = _world()
	var s: int = w.clock.tick
	_move(w, &"toy.ana", &"toy.workshop")
	_tick(w, 4)
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.home_a")
	_tick(w, 1)  # tick s+5: first edge done
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.yard")
	_tick(w, 9)  # tick s+14
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.yard")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	_tick(w, 1)  # tick s+15
	assert_int(w.clock.tick).is_equal(s + 15)
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.workshop")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(_last_outcome(w, &"toy.ana")).is_equal("success")


func test_departed_and_arrived_events_are_at_the_right_places_and_ticks() -> void:
	var w: NpcfWorld = _world()
	var s: int = w.clock.tick
	_move(w, &"toy.ana", &"toy.workshop")
	_tick(w, 15)
	var departed: Array[NpcfEvent] = _events(w, NpcfFramework.DEPARTED)
	var arrived: Array[NpcfEvent] = _events(w, NpcfFramework.ARRIVED)
	assert_int(departed.size()).is_equal(2)
	assert_int(arrived.size()).is_equal(2)
	if departed.size() == 2 and arrived.size() == 2:
		assert_str(String(departed[0].location)).is_equal("toy.home_a")
		assert_int(departed[0].tick).is_equal(s + 5)
		assert_str(String(arrived[0].location)).is_equal("toy.yard")
		assert_int(arrived[0].tick).is_equal(s + 5)
		assert_str(String(departed[1].location)).is_equal("toy.yard")
		assert_int(departed[1].tick).is_equal(s + 15)
		assert_str(String(arrived[1].location)).is_equal("toy.workshop")
		assert_int(arrived[1].tick).is_equal(s + 15)
		assert_array(arrived[1].actors).is_equal([&"toy.ana"])


func test_disembodied_move_resumes_from_the_last_reached_location_with_a_fresh_timer() -> void:
	var w: NpcfWorld = _world()
	var fake: FakeMovement = FakeMovement.new()
	fake.embodied = true
	w.adapters.movement = fake
	_move(w, &"toy.ana", &"toy.workshop")
	assert_int(fake.walks.size()).is_equal(1)
	assert_array(fake.walks[0]).is_equal([&"toy.yard", &"toy.workshop"])
	_tick(w, 3)  # embodied: the clock runs, nothing walks headlessly
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.home_a")
	# The adapter reports arrival at the yard, then the NPC leaves the body.
	w.travel.on_arrived(w, &"toy.ana", &"toy.yard")
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.yard")
	_tick(w, 2)
	w.travel.on_embodiment(w, &"toy.ana", false)
	fake.embodied = false
	_tick(w, 9)
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.yard")
	_tick(w, 1)
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.workshop")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()


func test_embodied_mover_finishes_when_it_reports_its_target() -> void:
	var w: NpcfWorld = _world()
	var fake: FakeMovement = FakeMovement.new()
	fake.embodied = true
	w.adapters.movement = fake
	_move(w, &"toy.ana", &"toy.yard")
	_tick(w, 20)  # no headless walking while embodied
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	w.travel.on_arrived(w, &"toy.ana", &"toy.yard")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(_last_outcome(w, &"toy.ana")).is_equal("success")


func test_player_arrives_through_an_arrived_input() -> void:
	var w: NpcfWorld = _world()
	assert_str(String(w.location_of(&"toy.player"))).is_equal("toy.yard")
	w.queue_input(NpcfInput.arrived(&"toy.player", &"toy.workshop"))
	w.step()
	assert_str(String(w.location_of(&"toy.player"))).is_equal("toy.workshop")
	var arrived: Array[NpcfEvent] = _events(w, NpcfFramework.ARRIVED)
	assert_int(arrived.size()).is_equal(1)
	if arrived.size() == 1:
		assert_str(String(arrived[0].location)).is_equal("toy.workshop")
	assert_int(_events(w, NpcfFramework.DEPARTED).size()).is_equal(1)


func test_a_move_to_the_current_location_succeeds_at_once() -> void:
	var w: NpcfWorld = _world()
	_move(w, &"toy.ana", &"toy.home_a")
	_tick(w, 1)
	assert_bool(w.npc(&"toy.ana").is_busy()).is_false()
	assert_str(_last_outcome(w, &"toy.ana")).is_equal("success")
	assert_int(_events(w, NpcfFramework.ARRIVED).size()).is_equal(0)
