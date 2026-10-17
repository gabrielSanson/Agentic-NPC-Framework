extends GdUnitTestSuite
## The world loop: phase order, input ordering, payload rejection, RNG isolation, scenario setup and
## invariant reporting. Uses the inline MiniPackFixture (loaded through the real loader).

const HOOKS: String = "res://tests/fixtures/hooks"
const PHASES: Array[StringName] = [&"clock", &"inputs", &"director", &"needs", &"actions", &"delivery", &"decisions", &"checks"]

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(world_seed: int = 1, cast_extra: Array[NpcfCastEntry] = [], facts: Array[NpcfFactSeed] = []) -> NpcfWorld:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var loaded: NpcfLoadResult = NpcfPackLoader.new().load_pack(m, NpcfVersion.FRAMEWORK, HOOKS)
	assert_bool(loaded.ok).override_failure_message(loaded.format_errors()).is_true()
	var s: NpcfScenarioDef = MiniPackFixture.scenario(m, cast_extra)
	s.facts = facts
	var w: NpcfWorld = NpcfWorldBuilder.build(loaded.pack, s, world_seed)
	_worlds.append(w)
	return w


func _event(kind: StringName, actor: StringName, location: StringName) -> NpcfEvent:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = kind
	e.actors = [actor]
	e.location = location
	return e


func _probe(seen: Array[StringName], phase: StringName) -> Callable:
	return func(_w: NpcfWorld) -> void: seen.append(phase)


func test_builder_places_npcs_in_sorted_order() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var bo: NpcfCastEntry = MiniPackFixture.cast_entry(MiniPackFixture.character(m, &"toy.bo"), MiniPackFixture.location(m, &"toy.yard"))
	var w: NpcfWorld = _world(1, [bo])
	assert_array(w.npc_ids).contains_exactly([&"toy.ana", &"toy.bo"])
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.home")
	assert_str(String(w.location_of(&"toy.bo"))).is_equal("toy.yard")
	assert_int(w.npc(&"toy.ana").needs[&"toy.energy"]).is_equal(700)
	assert_bool(w.is_entity(&"toy.ana")).is_true()
	assert_bool(w.is_entity(&"toy.nobody")).is_false()
	assert_bool(w.headless).is_true()
	assert_int(w.events.log.size()).is_equal(0)


func test_scenario_facts_are_applied_quietly() -> void:
	var m: NpcfPackManifest = MiniPackFixture.manifest()
	var seed_fact: NpcfFactSeed = NpcfFactSeed.new()
	seed_fact.fact = m.facts[0]
	seed_fact.subject = &"toy.ana"
	seed_fact.value = true
	var w: NpcfWorld = _world(1, [], [seed_fact] as Array[NpcfFactSeed])
	assert_bool(w.state.get_fact(&"toy.ana", &"toy.mood")).is_true()
	assert_int(w.events.log.size()).is_equal(0)


func test_phase_order_is_the_eight_named_phases() -> void:
	var w: NpcfWorld = _world()
	var report: NpcfTickReport = w.step()
	assert_int(report.tick).is_equal(1)
	assert_array(report.phases).is_equal(PHASES)


func test_phase_probes_run_after_each_phase_in_order() -> void:
	var w: NpcfWorld = _world()
	var seen: Array[StringName] = []
	for phase: StringName in PHASES:
		w.phase_probes[phase] = _probe(seen, phase)
	w.step()
	assert_array(seen).is_equal(PHASES)


func test_inputs_are_applied_in_arrival_order() -> void:
	var w: NpcfWorld = _world()
	var arrived: NpcfEvent = _event(NpcfFramework.ARRIVED, &"toy.ana", &"toy.home")
	var departed: NpcfEvent = _event(NpcfFramework.DEPARTED, &"toy.ana", &"toy.home")
	w.queue_input(NpcfInput.event_input(arrived))
	w.queue_input(NpcfInput.event_input(departed))
	var report: NpcfTickReport = w.step()
	assert_int(w.events.log.size()).is_equal(2)
	assert_object(w.events.log[0]).is_same(arrived)
	assert_object(w.events.log[1]).is_same(departed)
	assert_int(arrived.id).is_equal(1)
	assert_int(departed.id).is_equal(2)
	assert_int(arrived.tick).is_equal(report.tick)
	assert_int(w.inputs.size()).is_equal(0)


func test_inputs_queued_during_a_tick_wait_for_the_next_one() -> void:
	var w: NpcfWorld = _world()
	w.step()
	w.queue_input(NpcfInput.event_input(_event(NpcfFramework.ARRIVED, &"toy.ana", &"toy.home")))
	assert_int(w.events.log.size()).is_equal(0)
	w.step()
	assert_int(w.events.log.size()).is_equal(1)


func test_payload_rejection_names_the_field() -> void:
	var w: NpcfWorld = _world()
	var bad_type: NpcfEvent = NpcfEvent.new()
	bad_type.kind = NpcfFramework.TAGS_CHANGED
	bad_type.payload = {&"tag": 5, &"added": true}
	assert_int(w.emit(bad_type)).is_equal(-1)
	assert_str(w.events.last_error).contains("\"tag\"")

	var unknown: NpcfEvent = NpcfEvent.new()
	unknown.kind = NpcfFramework.ARRIVED
	unknown.payload = {&"extra": 1}
	assert_int(w.emit(unknown)).is_equal(-1)
	assert_str(w.events.last_error).contains("unknown field \"extra\"")
	assert_int(w.events.log.size()).is_equal(0)

	var good: NpcfEvent = NpcfEvent.new()
	good.kind = NpcfFramework.TAGS_CHANGED
	good.payload = {&"tag": &"toy.tired", &"added": true}
	assert_int(w.emit(good)).is_equal(1)
	assert_str(w.events.last_error).is_equal("")


func _draws(stream: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	for _i: int in 4:
		out.append(stream.randi())
	return out


func test_rng_streams_do_not_depend_on_other_streams() -> void:
	var alone: NpcfRng = NpcfRng.new(7)
	var first: Array[int] = _draws(alone.stream(&"sched", &"toy.a", &"phase"))

	var crowded: NpcfRng = NpcfRng.new(7)
	crowded.stream(&"sched", &"toy.b", &"phase").randi()
	crowded.stream(&"sched", &"toy.c", &"phase").randi()
	var second: Array[int] = _draws(crowded.stream(&"sched", &"toy.a", &"phase"))
	assert_array(second).is_equal(first)


func test_rng_streams_repeat_for_the_same_seed_and_differ_across_seeds() -> void:
	var w1: NpcfWorld = _world(42)
	var w2: NpcfWorld = _world(42)
	var w3: NpcfWorld = _world(43)
	var a: Array[int] = _draws(w1.rng.stream(&"sched", &"toy.ana", &"phase"))
	assert_array(_draws(w2.rng.stream(&"sched", &"toy.ana", &"phase"))).is_equal(a)
	assert_array(_draws(w3.rng.stream(&"sched", &"toy.ana", &"phase"))).is_not_equal(a)


func _failing_invariant() -> Callable:
	return func(w: NpcfWorld) -> Array[NpcfInvariantFailure]:
		var out: Array[NpcfInvariantFailure] = []
		out.append(NpcfInvariantFailure.make(&"toy.inv.inline", w.clock.tick, [] as Array[StringName], "inline check failed"))
		return out


func test_clean_world_reports_no_invariant_failures() -> void:
	var w: NpcfWorld = _world()
	var report: NpcfTickReport = w.step()
	assert_array(report.invariant_failures).is_empty()


func test_inline_invariant_failure_carries_id_and_tick() -> void:
	var w: NpcfWorld = _world()
	w.invariants.extra.append(_failing_invariant())
	w.step()
	var report: NpcfTickReport = w.step()
	assert_int(report.invariant_failures.size()).is_equal(1)
	if report.invariant_failures.size() == 1:
		var f: NpcfInvariantFailure = report.invariant_failures[0]
		assert_str(String(f.invariant_id)).is_equal("toy.inv.inline")
		assert_int(f.tick).is_equal(2)
		assert_str(f.format()).is_equal("invariant toy.inv.inline failed at tick 2 for []: inline check failed")


func test_framework_invariant_catches_npc_at_unknown_location() -> void:
	var w: NpcfWorld = _world()
	w.state.write(&"toy.ana", NpcfFramework.AT, &"toy.nowhere")
	var report: NpcfTickReport = w.step()
	assert_int(report.invariant_failures.size()).is_equal(1)
	if report.invariant_failures.size() == 1:
		assert_str(String(report.invariant_failures[0].invariant_id)).is_equal("npcf.inv.location")
		assert_str(String(report.invariant_failures[0].entities[0])).is_equal("toy.ana")
