extends GdUnitTestSuite
## Memory: delivery remembers events at or above the threshold with the event's provenance, the log keeps its
## cap by dropping the least salient record (oldest first among equals), and retrieval ranks records by recency,
## salience and subject overlap.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## The toy world with Ana, Bo and Cy (Ana and Cy at home_a, Bo at home_b).
func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _emit(w: NpcfWorld, kind: StringName, location: StringName, actors: Array[StringName]) -> void:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = kind
	e.location = location
	e.actors = actors
	w.emit(e)


func _record(log: NpcfMemoryLog, salience: int, tick: int) -> NpcfMemoryRecord:
	var r: NpcfMemoryRecord = NpcfMemoryRecord.new()
	r.salience = salience
	r.tick = tick
	log.append(r)
	return r


func test_threshold_remembers_only_events_at_or_above_it() -> void:
	var w: NpcfWorld = _world()
	w.sim.memory_threshold = 50
	_emit(w, &"toy.spotted", &"toy.home_a", [] as Array[StringName])
	_emit(w, &"toy.chatted", &"toy.home_a", [&"toy.ana"] as Array[StringName])
	w.step()
	for id: StringName in [&"toy.ana", &"toy.cy"]:
		var n: NpcfNpcState = w.npc(id)
		assert_int(n.memory.size()).override_failure_message(String(id)).is_equal(1)
		if n.memory.size() != 1:
			continue
		var r: NpcfMemoryRecord = n.memory.records[0]
		assert_str(String(r.kind)).is_equal("toy.spotted")
		assert_str(String(r.message_key)).is_equal("toy.spotted")
		assert_int(r.source).is_equal(NpcfBelief.Source.WITNESSED)
		assert_str(String(r.location)).is_equal("toy.home_a")
	assert_int(w.npc(&"toy.bo").memory.size()).is_equal(0)


func test_cap_drops_the_least_salient_then_the_oldest() -> void:
	var log: NpcfMemoryLog = NpcfMemoryLog.new()
	log.cap = 3
	_record(log, 50, 1)
	_record(log, 20, 2)
	_record(log, 50, 3)
	_record(log, 20, 4)
	var ids: Array[int] = []
	for r: NpcfMemoryRecord in log.records:
		ids.append(r.id)
	assert_array(ids).is_equal([1, 3, 4])
	_record(log, 10, 5)
	ids.clear()
	for r: NpcfMemoryRecord in log.records:
		ids.append(r.id)
	assert_array(ids).is_equal([1, 3, 4])


func test_retrieval_ranks_by_recency_salience_and_subject_overlap() -> void:
	var sim: NpcfSimConfig = NpcfSimConfig.new()
	sim.retrieval_w_recency = 1.0
	sim.retrieval_w_salience = 1.0
	sim.retrieval_w_subject = 1.0
	sim.retrieval_half_life_ticks = 100
	var log: NpcfMemoryLog = NpcfMemoryLog.new()
	var a: NpcfMemoryRecord = _record(log, 100, 0)
	a.subjects = [&"x"] as Array[StringName]
	var b: NpcfMemoryRecord = _record(log, 0, 90)
	b.subjects = [&"y"] as Array[StringName]
	var c: NpcfMemoryRecord = _record(log, 50, 100)
	c.subjects = [&"x", &"y"] as Array[StringName]
	var top: Array[NpcfMemoryRecord] = NpcfMemoryRetrieval.top(log, [&"x"] as Array[StringName], 100, 2, sim)
	assert_int(top.size()).is_equal(2)
	if top.size() == 2:
		# A and C both score 2.5; the tie goes to the lower ID, so A comes first.
		assert_int(top[0].id).is_equal(a.id)
		assert_int(top[1].id).is_equal(c.id)


func test_empty_subject_list_gives_no_overlap_term() -> void:
	var sim: NpcfSimConfig = NpcfSimConfig.new()
	sim.retrieval_half_life_ticks = 100
	var log: NpcfMemoryLog = NpcfMemoryLog.new()
	var about_x: NpcfMemoryRecord = _record(log, 0, 100)
	about_x.subjects = [&"x", &"y"] as Array[StringName]
	var plain: NpcfMemoryRecord = _record(log, 50, 100)
	var top: Array[NpcfMemoryRecord] = NpcfMemoryRetrieval.top(log, [] as Array[StringName], 100, 1, sim)
	assert_int(top.size()).is_equal(1)
	if top.size() == 1:
		assert_int(top[0].id).is_equal(plain.id)
