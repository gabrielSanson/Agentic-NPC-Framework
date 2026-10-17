extends GdUnitTestSuite
## Event log equivalence: toy.basic, seed 1, 240 ticks, must reproduce the committed golden log byte for
## byte (tests/fixtures/golden/toy_basic_seed1_240.log, the CLI `run --log` format). Performance changes to
## delivery, needs or perception must keep this green; a deliberate behavior change regenerates the file.

const GOLDEN: String = "res://tests/fixtures/golden/toy_basic_seed1_240.log"
const TICKS: int = 240


func test_toy_basic_seed1_log_matches_golden_file() -> void:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	for _i: int in TICKS:
		w.step()
	var actual: String = w.events.log_text() + "\n"
	w.dispose()
	assert_str(actual).is_equal(FileAccess.get_file_as_string(GOLDEN))
