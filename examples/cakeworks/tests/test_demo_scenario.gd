extends GdUnitTestSuite
## The demo scenario (seven NPCs) runs one headless day with no invariant failures, and every NPC completes at least
## one cw.work_shift in that day. Only the event log is read for the shifts; cw.shift_completed is emitted on success only.

const DAY_TICKS: int = 1440
const SHIFT_DONE: StringName = &"cw.shift_completed"


func test_demo_day_runs_without_errors_and_every_npc_completes_a_shift() -> void:
	var w: NpcfWorld = NpcfWorldBuilder.build(CwFixture.load_pack(), CwFixture.demo(), 1)
	var failures: int = 0
	for _i: int in DAY_TICKS:
		var report: NpcfTickReport = w.step()
		failures += report.invariant_failures.size()
	assert_int(failures).is_equal(0)
	var worked: Dictionary[StringName, bool] = {}
	for e: NpcfEvent in w.events.log:
		if e.kind == SHIFT_DONE and not e.actors.is_empty() and e.tick >= 0 and e.tick < DAY_TICKS:
			worked[e.actors[0]] = true
	w.dispose()
	var npcs: Array[StringName] = CwFixture.demo_npcs()
	assert_int(npcs.size()).is_equal(7)
	for id: StringName in npcs:
		assert_bool(worked.has(id)).override_failure_message("%s completed no cw.work_shift in the first day" % str(id)).is_true()
