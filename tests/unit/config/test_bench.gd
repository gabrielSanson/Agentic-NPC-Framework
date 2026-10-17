extends GdUnitTestSuite
## The bench population: clones of the basic cast, each with its own archetype copy deciding every tick, loaded
## through the real loader; and the bench arithmetic (percentiles and the capped-frame count).

const MANIFEST: String = "res://packs/toy/pack.tres"
const BASIC: String = "res://packs/toy/scenarios/basic.tres"


func _source() -> Array:
	var manifest: NpcfPackManifest = ResourceLoader.load(MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	var scenario: NpcfScenarioDef = ResourceLoader.load(BASIC, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	return [manifest, scenario]


func test_population_loads_with_zero_errors_and_clones_the_cast() -> void:
	var source: Array = _source()
	var manifest: NpcfPackManifest = source[0]
	var scenario: NpcfScenarioDef = source[1]
	var population: NpcfBench.Population = NpcfBench.population(manifest, scenario, 7)
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	var loaded: NpcfLoadResult = loader.load_pack(population.manifest, NpcfVersion.FRAMEWORK, manifest.resource_path.get_base_dir())
	assert_str(loaded.format_errors()).is_equal("")
	assert_bool(loaded.ok).is_true()
	assert_array(loader.check_scenario(loaded.pack, population.scenario)).is_empty()
	assert_int(population.scenario.cast.size()).is_equal(7)
	var first: NpcfCastEntry = population.scenario.cast[0]
	assert_str(String(first.character.id)).is_equal("toy.bench_00")
	assert_int(first.character.archetype.decision_period_ticks).is_equal(1)
	# The source archetype is untouched: the clones carry copies.
	assert_int(manifest.archetypes[0].decision_period_ticks).is_greater(1)


func test_population_keeps_the_source_cast_order() -> void:
	var source: Array = _source()
	var manifest: NpcfPackManifest = source[0]
	var scenario: NpcfScenarioDef = source[1]
	var population: NpcfBench.Population = NpcfBench.population(manifest, scenario, 4)
	var entry: NpcfCastEntry = population.scenario.cast[3]
	assert_str(String(entry.character.id)).is_equal("toy.bench_03")
	assert_str(String(entry.start_location.id)).is_equal(String(scenario.cast[0].start_location.id))


func test_percentile_uses_nearest_rank() -> void:
	var sorted: Array[float] = [1.0, 2.0, 3.0, 4.0]
	assert_float(NpcfBench.percentile(sorted, 0.5)).is_equal(2.0)
	assert_float(NpcfBench.percentile(sorted, 0.99)).is_equal(4.0)
	assert_float(NpcfBench.percentile(sorted, 0.0)).is_equal(1.0)


func test_capped_frames_counts_frames_that_cannot_drain_their_time() -> void:
	# 10 s of owed time in one frame, two ticks allowed per frame: the frame is capped, then drains.
	assert_int(NpcfBench.capped_frames(1, 10.0, 1.0, 1.0, 2)).is_equal(1)
	assert_int(NpcfBench.capped_frames(1, 1.0 / 60.0, 16.0, 1.0, 2)).is_equal(0)
