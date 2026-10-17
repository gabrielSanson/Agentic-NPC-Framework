extends GdUnitTestSuite
## Determinism of the full toy day: two worlds with the same seed write identical event logs over
## 1,440 ticks. A different seed is allowed to differ and is not asserted.

const TICKS: int = 1440


func _log(world_seed: int) -> String:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), world_seed)
	for _i: int in TICKS:
		w.step()
	var text: String = w.events.log_text()
	w.dispose()
	return text


func test_same_seed_gives_identical_event_logs() -> void:
	var first: String = _log(7)
	var second: String = _log(7)
	assert_int(first.length()).is_greater(0)
	assert_str(second).is_equal(first)
