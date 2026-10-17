extends GdUnitTestSuite
## The cw hook scripts, run against a world built from the smoke scenario.
## Smoke start: Mira and Oskar on the production floor, Juno alone in the lounge.
## Preconditions run on a truth view (the executor's view at action start, R5.5), so the tests use one too.

const SOMEONE_HERE: String = "res://packs/cw/hooks/cw_someone_here.gd"
const NEWS: String = "res://packs/cw/hooks/cw_news.gd"


func test_someone_here_is_false_when_alone_and_true_with_a_second_crew_member() -> void:
	var w: NpcfWorld = NpcfWorldBuilder.build(CwFixture.load_pack(), CwFixture.smoke(), 1)
	var script: GDScript = load(SOMEONE_HERE) as GDScript
	assert_object(script).is_not_null()
	var hook: NpcfConditionHook = script.new()
	var args: Dictionary[StringName, Variant] = {}
	assert_bool(hook.check(w.view(&"cw.juno").as_truth(), args)).is_false()
	assert_bool(hook.check(w.view(&"cw.mira").as_truth(), args)).is_true()
	w.dispose()


func test_news_has_nothing_to_reveal_at_the_start() -> void:
	var w: NpcfWorld = NpcfWorldBuilder.build(CwFixture.load_pack(), CwFixture.smoke(), 1)
	var script: GDScript = load(NEWS) as GDScript
	assert_object(script).is_not_null()
	var hook: NpcfIntentHook = script.new()
	var o: NpcfRuleOutcome = hook.outcome(w.view(&"cw.mira"), &"cw.ask_news", &"cw.player")
	assert_str(str(o.result)).is_equal("cw.no_news")
	assert_int(o.revealed.size()).is_equal(0)
	w.dispose()
