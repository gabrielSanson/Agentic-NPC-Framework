extends GdUnitTestSuite
## The cw pack loads with zero errors, has the planned content counts, every ID starts with cw.,
## and one headless day with the smoke scenario runs without an invariant failure.

const DAY_TICKS: int = 1440


func _manifest() -> NpcfPackManifest:
	return ResourceLoader.load(CwFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest


func test_manifest_and_smoke_scenario_load_with_zero_errors() -> void:
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(_manifest())
	assert_bool(result.ok).is_true()
	assert_str(result.format_errors()).is_equal("")
	var errors: Array[NpcfConfigError] = NpcfPackLoader.new().check_scenario(result.pack, CwFixture.smoke())
	assert_int(errors.size()).is_equal(0)


func test_content_counts_match_the_plan() -> void:
	var m: NpcfPackManifest = _manifest()
	assert_int(m.needs.size()).is_equal(3)
	assert_int(m.location_graph.locations.size()).is_equal(3)
	assert_int(m.actions.size()).is_equal(7)
	assert_int(m.goals.size()).is_equal(5)
	assert_int(m.archetypes.size()).is_equal(3)
	assert_int(m.personalities.size()).is_equal(3)
	assert_int(m.characters.size()).is_equal(8)


func test_every_id_starts_with_cw() -> void:
	var m: NpcfPackManifest = _manifest()
	var ids: Array[StringName] = []
	for f: NpcfFactDef in m.facts:
		ids.append(f.id)
	for n: NpcfNeedDef in m.needs:
		ids.append(n.id)
	for e: NpcfEventKindDef in m.event_kinds:
		ids.append(e.id)
	for g: NpcfGoalDef in m.goals:
		ids.append(g.id)
	for a: NpcfActionDef in m.actions:
		ids.append(a.id)
	for ar: NpcfArchetypeDef in m.archetypes:
		ids.append(ar.id)
	for p: NpcfPersonalityDef in m.personalities:
		ids.append(p.id)
	for c: NpcfCharacterDef in m.characters:
		ids.append(c.id)
	for l: NpcfLocationDef in m.location_graph.locations:
		ids.append(l.id)
	for s: NpcfScheduleDef in m.schedules:
		ids.append(s.id)
	assert_int(ids.size()).is_greater(0)
	for id: StringName in ids:
		assert_bool(str(id).begins_with("cw.")).is_true()


func test_one_headless_day_runs_without_invariant_failures() -> void:
	var w: NpcfWorld = NpcfWorldBuilder.build(CwFixture.load_pack(), CwFixture.smoke(), 1)
	var failures: int = 0
	var decisions: int = 0
	for _i: int in DAY_TICKS:
		var report: NpcfTickReport = w.step()
		failures += report.invariant_failures.size()
		decisions += report.decisions
	w.dispose()
	assert_int(failures).is_equal(0)
	assert_int(decisions).is_greater(0)
