extends GdUnitTestSuite
## The NPC trace (C5c 5.1): every field is present, the trace never changes a run, dialogue records appear in it, and
## the trace command line prints it as JSON and exits 1 for an unknown NPC.

const CLI: String = "res://addons/npcf/tools/npcf_cli.gd"
const ANA: StringName = &"toy.ana"
const TRACE_KEYS: Array[String] = [
	"npc", "tick", "time", "config", "needs", "location", "tags", "goal", "action", "running", "action_elapsed",
	"plan", "beliefs", "directives", "decisions", "outcomes", "dialogue", "hook_failures",
]

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(pack: NpcfLoadedPack, world_seed: int) -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), world_seed)
	_worlds.append(w)
	return w


func _run(w: NpcfWorld, ticks: int) -> void:
	for _i: int in ticks:
		w.step()


func test_trace_has_every_field() -> void:
	var w: NpcfWorld = _world(ToyFixture.load_pack(), 2)
	_run(w, 200)
	var t: Dictionary = NpcfTraceService.trace(w, ANA)
	for key: String in TRACE_KEYS:
		assert_bool(t.has(key)).override_failure_message("missing trace key " + key).is_true()
	assert_str(str(t["npc"])).is_equal("toy.ana")
	var tick: int = t["tick"]
	assert_int(tick).is_equal(200)
	var config: Dictionary = t["config"]
	assert_bool(config.has("goals")).is_true()
	var failures: Dictionary = t["hook_failures"]
	assert_bool(failures.has("total")).is_true()
	var beliefs: Array = t["beliefs"]
	assert_bool(beliefs.size() > 0).is_true()
	for entry: Variant in beliefs:
		var b: Dictionary = entry
		assert_bool(b.has("source") and b.has("confidence")).is_true()


func test_trace_does_not_change_results() -> void:
	var traced: NpcfWorld = _world(ToyFixture.load_pack(), 4)
	var plain: NpcfWorld = _world(ToyFixture.load_pack(), 4)
	traced.phase_probes[&"checks"] = func(w: NpcfWorld) -> void:
		for id: StringName in w.npc_ids:
			NpcfTraceService.trace(w, id)
	_run(traced, 300)
	_run(plain, 300)
	assert_str(traced.events.log_text()).is_not_empty()
	assert_str(traced.events.log_text()).is_equal(plain.events.log_text())


func test_unknown_npc_gives_empty() -> void:
	var w: NpcfWorld = _world(ToyFixture.load_pack(), 2)
	_run(w, 10)
	assert_bool(NpcfTraceService.trace(w, &"toy.nobody").is_empty()).is_true()


func test_dialogue_records_in_trace() -> void:
	var w: NpcfWorld = _world(DialogueFixture.load_pack(), 1)
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.player", NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	w.step()
	var t: Dictionary = NpcfTraceService.trace(w, ANA)
	var turns: Array = t["dialogue"]
	assert_int(turns.size()).is_equal(1)
	var turn: Dictionary = turns[0]
	assert_str(str(turn["intent"])).is_not_empty()


func _cli_trace(npc: String) -> Array:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", CLI, "--", "trace", "--manifest", ToyFixture.MANIFEST,
		"--scenario", "res://packs/toy/scenarios/basic.tres", "--seed", "1", "--tick", "50", "--npc", npc,
	])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	return [code, "\n".join(PackedStringArray(output))]


func test_cli_trace_prints_json_for_a_known_npc() -> void:
	var result: Array = _cli_trace("toy.ana")
	assert_int(result[0]).is_equal(0)
	var text: String = result[1]
	var start: int = text.find("{")
	var end: int = text.rfind("}")
	assert_bool(start >= 0 and end > start).is_true()
	var parsed: Variant = JSON.parse_string(text.substr(start, end - start + 1))
	assert_bool(parsed is Dictionary).is_true()
	var d: Dictionary = parsed
	assert_str(str(d["npc"])).is_equal("toy.ana")


func test_cli_trace_exits_1_for_an_unknown_npc() -> void:
	var result: Array = _cli_trace("toy.nobody")
	assert_int(result[0]).is_equal(1)
	assert_str(str(result[1])).contains("unknown npc toy.nobody")
