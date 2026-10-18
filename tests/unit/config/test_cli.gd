extends GdUnitTestSuite
## The `check` command exits 1 with the error text for a broken manifest and 0 for a valid one.
## Runs the real command line in a child Godot process.

const CLI: String = "res://addons/npcf/tools/npcf_cli.gd"


func _check(manifest: String) -> Array:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", CLI, "--", "check", "--manifest", manifest,
	])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	return [code, "\n".join(PackedStringArray(output))]


func test_check_fails_on_broken_manifest() -> void:
	var result: Array = _check("res://tests/fixtures/broken/bad_namespace.tres")
	assert_int(result[0]).is_equal(1)
	assert_str(result[1]).contains("res://tests/fixtures/broken/bad_namespace.tres: pack_namespace: \"Bad\" is not a valid namespace")


func _run(manifest: String, scenario: String, ticks: String) -> Array:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", CLI, "--", "run", "--manifest", manifest, "--scenario", scenario, "--seed", "1", "--ticks", ticks,
	])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	return [code, "\n".join(PackedStringArray(output))]


func test_run_exits_one_on_the_first_tick_with_an_invariant_failure() -> void:
	var result: Array = _run("res://tests/fixtures/invariant_pack/pack.tres", "res://tests/fixtures/invariant_pack/scenario.tres", "5")
	assert_int(result[0]).is_equal(1)
	assert_str(result[1]).contains("invariant fixture.inv.broken failed at tick 1 for []: always fails")
	assert_str(result[1]).not_contains("ran 5 ticks")


func test_check_passes_on_valid_manifest() -> void:
	var result: Array = _check("res://tests/fixtures/broken/empty_pack.tres")
	assert_int(result[0]).is_equal(0)
	assert_str(result[1]).contains("ok: 0 definitions")


func _bench(args: PackedStringArray) -> Array:
	var output: Array = []
	var full: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CLI, "--", "bench",
	])
	full.append_array(args)
	var code: int = OS.execute(OS.get_executable_path(), full, output, true)
	return [code, "\n".join(PackedStringArray(output))]


func test_bench_exits_zero_and_prints_median() -> void:
	var result: Array = _bench(PackedStringArray([
		"--manifest", "res://packs/toy/pack.tres", "--scenario", "res://packs/toy/scenarios/basic.tres",
		"--npcs", "5", "--ticks", "60",
	]))
	assert_int(result[0]).is_equal(0)
	assert_str(result[1]).contains("median_ms=")
	assert_str(result[1]).contains("capped_frames_at_speed_16=")
	assert_str(result[1]).contains("max_decisions_per_tick=4 checks=interval")


func test_bench_takes_a_cap_and_every_tick_checks() -> void:
	var result: Array = _bench(PackedStringArray([
		"--manifest", "res://packs/toy/pack.tres", "--scenario", "res://packs/toy/scenarios/basic.tres",
		"--npcs", "5", "--ticks", "30", "--cap", "2", "--checks", "every-tick",
	]))
	assert_int(result[0]).is_equal(0)
	assert_str(result[1]).contains("max_decisions_per_tick=2 checks=every-tick")


func test_bench_rejects_an_unknown_checks_mode() -> void:
	var result: Array = _bench(PackedStringArray([
		"--manifest", "res://packs/toy/pack.tres", "--scenario", "res://packs/toy/scenarios/basic.tres",
		"--checks", "sometimes",
	]))
	assert_int(result[0]).is_equal(2)
