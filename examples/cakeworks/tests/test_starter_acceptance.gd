extends GdUnitTestSuite
## Acceptance for the starter scenario (C6b). Every seed in seeds.txt runs three days (4,320 ticks) headless with
## no providers. Assertions read only the event log and the belief stores:
##   1. no invariant failure;
##   2. every starter NPC completes a cw.work_shift on each day 0..2 (cw.shift_completed is emitted only on success);
##   3. at least one NPC who was not a witness of a cw.complaint holds a rumor (TOLD_BY) about that complaint.
## Witnesses are recorded in the delivery phase, from the same recipients the delivery phase uses.

const DAY_TICKS: int = 1440
const DAYS: int = 3
const SEEDS_PATH: String = "res://tests/seeds.txt"
const SHIFT_DONE: StringName = &"cw.shift_completed"
const COMPLAINT: StringName = &"cw.complaint"
const COMPLAINED: StringName = &"cw.complained"


func test_starter_acceptance_holds_for_every_seed() -> void:
	var seeds: Array[int] = _seeds()
	assert_int(seeds.size()).is_equal(5)
	for seed_value: int in seeds:
		_check_seed(seed_value)


func _seeds() -> Array[int]:
	var out: Array[int] = []
	var text: String = FileAccess.get_file_as_string(SEEDS_PATH)
	for line: String in text.split("\n", false):
		var t: String = line.strip_edges()
		if t != "" and t.is_valid_int():
			out.append(t.to_int())
	return out


func _check_seed(seed_value: int) -> void:
	var started_ms: int = Time.get_ticks_msec()
	var w: NpcfWorld = NpcfWorldBuilder.build(CwFixture.load_pack(), CwFixture.starter(), seed_value)
	var witnessed: Dictionary[String, bool] = {}
	var complaints: Array[NpcfEvent] = []
	var cursor: Array[int] = [0]
	var failures: Array[int] = [0]
	w.phase_probes[&"delivery"] = func(world: NpcfWorld) -> void:
		_record_witnesses(world, cursor, complaints, witnessed)
	for _i: int in DAYS * DAY_TICKS:
		var report: NpcfTickReport = w.step()
		failures[0] += report.invariant_failures.size()
	var shift_days: Dictionary[String, bool] = _shift_days(w)
	var rumor: bool = _has_rumor(w, complaints, witnessed)
	var ms: int = Time.get_ticks_msec() - started_ms
	print("ACCEPT seed=%d ms=%d events=%d complaints=%d rumor=%s" % [seed_value, ms, w.events.log.size(), complaints.size(), str(rumor)])
	w.dispose()

	assert_int(failures[0]).override_failure_message("seed %d: invariant failures" % seed_value).is_equal(0)
	for id: StringName in CwFixture.starter_npcs():
		for d: int in DAYS:
			var key: String = "%s:%d" % [str(id), d]
			assert_bool(shift_days.has(key)).override_failure_message("seed %d: %s completed no cw.work_shift on day %d" % [seed_value, str(id), d]).is_true()
	assert_bool(rumor).override_failure_message("seed %d: no non-witness holds a rumor about a complaint" % seed_value).is_true()


## Runs after the delivery phase: records the witnesses of every complaint logged since the last call.
func _record_witnesses(world: NpcfWorld, cursor: Array[int], complaints: Array[NpcfEvent], witnessed: Dictionary[String, bool]) -> void:
	for i: int in range(cursor[0], world.events.log.size()):
		var e: NpcfEvent = world.events.log[i]
		if e.kind != COMPLAINT:
			continue
		complaints.append(e)
		var found: Dictionary[StringName, int] = world.delivery.recipients(world, e)
		for id: StringName in found:
			var src: int = found[id]
			if src == NpcfBelief.Source.WITNESSED or src == NpcfBelief.Source.PARTICIPANT:
				witnessed["%d:%s" % [e.id, str(id)]] = true
	cursor[0] = world.events.log.size()


## "npc:day" keys for every cw.shift_completed in the log.
func _shift_days(w: NpcfWorld) -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	for e: NpcfEvent in w.events.log:
		if e.kind == SHIFT_DONE and not e.actors.is_empty():
			out["%s:%d" % [str(e.actors[0]), e.tick / DAY_TICKS]] = true
	return out


## True when some NPC who was not a witness of a complaint holds a TOLD_BY belief about that complaint.
func _has_rumor(w: NpcfWorld, complaints: Array[NpcfEvent], witnessed: Dictionary[String, bool]) -> bool:
	for e: NpcfEvent in complaints:
		if e.actors.is_empty():
			continue
		var actor: StringName = e.actors[0]
		for id: StringName in w.npc_ids:
			if id == actor or witnessed.has("%d:%s" % [e.id, str(id)]):
				continue
			var b: NpcfBelief = w.npc(id).beliefs.get_belief(actor, COMPLAINED)
			if b != null and b.source == NpcfBelief.Source.TOLD_BY and b.event_id == e.id:
				return true
	return false
