extends GdUnitTestSuite
## The toy pack loads, its basic scenario checks clean, the resolver merges its personalities and the
## command line accepts it.

const CLI: String = "res://addons/npcf/tools/npcf_cli.gd"


func test_toy_pack_loads_with_zero_errors() -> void:
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert_object(manifest).is_not_null()
	if manifest == null:
		return
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(manifest)
	assert_str(result.format_errors()).is_equal("")
	assert_bool(result.ok).is_true()


func test_basic_scenario_checks_with_zero_errors() -> void:
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var errors: Array[NpcfConfigError] = loader.check_scenario(pack, ToyFixture.basic())
	assert_int(errors.size()).is_equal(0)


func test_resolved_ana_multiplies_both_personalities() -> void:
	var scenario: NpcfScenarioDef = ToyFixture.basic()
	var ana: NpcfCastEntry = null
	for entry: NpcfCastEntry in scenario.cast:
		if entry.character.id == &"toy.ana":
			ana = entry
	assert_object(ana).is_not_null()
	if ana == null:
		return
	var resolved: NpcfResolvedCharacter = NpcfResolver.resolve(ana)
	assert_float(resolved.goal_multipliers[&"toy.rest"]).is_equal_approx(1.2, 0.000001)
	assert_str(String(resolved.start_location)).is_equal("toy.home_a")


func _run_cli(args: PackedStringArray) -> Array:
	var output: Array = []
	var full: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CLI, "--",
	])
	full.append_array(args)
	var code: int = OS.execute(OS.get_executable_path(), full, output, true)
	return [code, "\n".join(PackedStringArray(output))]


func test_cli_check_accepts_the_toy_pack() -> void:
	var result: Array = _run_cli(PackedStringArray(["check", "--manifest", ToyFixture.MANIFEST, "--scenario", ToyFixture.BASIC]))
	assert_int(result[0]).is_equal(0)
	assert_str(result[1]).contains("ok: ")
