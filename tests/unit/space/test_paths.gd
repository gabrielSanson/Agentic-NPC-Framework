extends GdUnitTestSuite
## Shortest paths over the location graph (Dijkstra with ID tie-break), unreachable pairs, and graph
## validation errors that carry the resource path. Uses the toy graph and small inline graphs.


func _loc(id: StringName) -> NpcfLocationDef:
	var l: NpcfLocationDef = NpcfLocationDef.new()
	l.id = id
	return l


func _edge(a: NpcfLocationDef, b: NpcfLocationDef, ticks: int) -> NpcfEdgeDef:
	var e: NpcfEdgeDef = NpcfEdgeDef.new()
	e.from_location = a
	e.to_location = b
	e.travel_ticks = ticks
	return e


func _graph(locations: Array[NpcfLocationDef], edges: Array[NpcfEdgeDef]) -> NpcfLocationGraph:
	var g: NpcfLocationGraph = NpcfLocationGraph.new()
	g.locations = locations
	g.edges = edges
	return g


func test_toy_graph_totals_and_paths() -> void:
	var index: NpcfLocationIndex = ToyFixture.load_pack().location_index
	assert_int(index.travel_ticks(&"toy.home_a", &"toy.workshop")).is_equal(15)
	assert_int(index.travel_ticks(&"toy.home_b", &"toy.workshop")).is_equal(17)
	assert_int(index.travel_ticks(&"toy.home_a", &"toy.home_b")).is_equal(12)
	assert_int(index.travel_ticks(&"toy.yard", &"toy.yard")).is_equal(0)
	assert_array(index.path(&"toy.home_a", &"toy.workshop").nodes).is_equal([&"toy.yard", &"toy.workshop"])
	assert_array(index.path(&"toy.home_a", &"toy.home_b").nodes).is_equal([&"toy.yard", &"toy.home_b"])
	assert_array(index.path(&"toy.yard", &"toy.yard").nodes).is_empty()
	assert_int(index.edge_ticks(&"toy.home_a", &"toy.yard")).is_equal(5)
	assert_int(index.edge_ticks(&"toy.yard", &"toy.home_a")).is_equal(5)
	assert_int(index.edge_ticks(&"toy.home_a", &"toy.workshop")).is_equal(-1)


func test_tie_is_broken_by_the_lower_location_id() -> void:
	var s: NpcfLocationDef = _loc(&"toy.s")
	var b: NpcfLocationDef = _loc(&"toy.b")
	var c: NpcfLocationDef = _loc(&"toy.c")
	var d: NpcfLocationDef = _loc(&"toy.d")
	var g: NpcfLocationGraph = _graph([s, b, c, d] as Array[NpcfLocationDef],
			[_edge(s, c, 1), _edge(s, b, 1), _edge(c, d, 1), _edge(b, d, 1)] as Array[NpcfEdgeDef])
	var index: NpcfLocationIndex = NpcfLocationIndex.new(g)
	assert_int(index.travel_ticks(&"toy.s", &"toy.d")).is_equal(2)
	assert_array(index.path(&"toy.s", &"toy.d").nodes).is_equal([&"toy.b", &"toy.d"])


func test_unreachable_location_has_no_path_and_negative_ticks() -> void:
	var index: NpcfLocationIndex = ToyFixture.load_pack().location_index
	assert_int(index.travel_ticks(&"toy.home_a", &"toy.nowhere")).is_equal(-1)
	assert_object(index.path(&"toy.home_a", &"toy.nowhere")).is_null()
	var a: NpcfLocationDef = _loc(&"toy.a")
	var island: NpcfLocationDef = _loc(&"toy.island")
	var g: NpcfLocationGraph = _graph([a, island] as Array[NpcfLocationDef], [] as Array[NpcfEdgeDef])
	var lonely: NpcfLocationIndex = NpcfLocationIndex.new(g)
	assert_int(lonely.travel_ticks(&"toy.a", &"toy.island")).is_equal(-1)
	assert_object(lonely.path(&"toy.a", &"toy.island")).is_null()


func test_nearest_with_tag_skips_unreachable_places() -> void:
	var index: NpcfLocationIndex = ToyFixture.load_pack().location_index
	assert_str(String(index.nearest_with_tag(&"toy.home_b", &"toy.work_place"))).is_equal("toy.workshop")
	assert_str(String(index.nearest_with_tag(&"toy.home_b", &"toy.nothing_here"))).is_equal("")


func _manifest_with_graph_change(mutate: Callable) -> NpcfPackManifest:
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	mutate.call(manifest.location_graph)
	return manifest


func test_unknown_edge_endpoint_is_reported_with_its_file() -> void:
	var manifest: NpcfPackManifest = _manifest_with_graph_change(func(g: NpcfLocationGraph) -> void:
		g.edges.append(_edge(g.locations[0], _loc(&"toy.ghost"), 3)))
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(manifest)
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("res://packs/toy/locations/graph.tres")
	assert_str(result.format_errors()).contains("unknown location \"toy.ghost\"")


func test_zero_travel_time_is_reported() -> void:
	var manifest: NpcfPackManifest = _manifest_with_graph_change(func(g: NpcfLocationGraph) -> void:
		g.edges[0].travel_ticks = 0)
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(manifest)
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("res://packs/toy/locations/graph.tres")
	assert_str(result.format_errors()).contains("0 must be at least 1")


func test_location_unreachable_from_the_scenario_is_reported() -> void:
	var manifest: NpcfPackManifest = _manifest_with_graph_change(func(g: NpcfLocationGraph) -> void:
		var island: NpcfLocationDef = _loc(&"toy.island")
		g.locations.append(island))
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	var result: NpcfLoadResult = loader.load_pack(manifest)
	assert_bool(result.ok).is_true()
	var errors: Array[NpcfConfigError] = loader.check_scenario(result.pack, ToyFixture.basic())
	var text: String = "\n".join(errors.map(func(e: NpcfConfigError) -> String: return e.format()))
	assert_str(text).contains("location \"toy.island\" is unreachable from the scenario's start locations")
