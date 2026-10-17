extends GdUnitTestSuite
## The save codec: value tags, header checks, restore validation, and encode-restore-encode identity.

const SEED: int = 7


func _world(world_seed: int) -> NpcfWorld:
	return NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), world_seed)


func _text_after(world_seed: int, ticks: int) -> String:
	var w: NpcfWorld = _world(world_seed)
	for _i: int in ticks:
		w.step()
	var text: String = NpcfSaveCodec.to_text(NpcfSaveCodec.encode(w))
	w.dispose()
	return text


func test_values_round_trip() -> void:
	var values: Array = [null, true, -5, 9223372036854775807, 1.25, 0.1, &"toy.x", "text"]
	for v: Variant in values:
		var tagged: Variant = NpcfSaveCodec.encode_value(v, "round trip")
		assert_bool(tagged != null).is_true()
		var res: Array = NpcfSaveCodec.decode_value(tagged, "round trip")
		assert_bool(res[0]).is_true()
		assert_int(typeof(res[1])).is_equal(typeof(v))
		assert_that(res[1]).is_equal(v)


func test_unsupported_value_type_is_reported() -> void:
	var tagged: Variant = NpcfSaveCodec.encode_value(Vector2(1, 2), "x")
	assert_that(tagged).is_null()
	assert_str(NpcfSaveCodec.last_error()).is_equal("unsupported value type Vector2 at x")


func test_as_int_rejects_fractions() -> void:
	var ok: Array = NpcfSaveCodec.as_int(3.0, "n")
	assert_bool(ok[0]).is_true()
	assert_int(ok[1]).is_equal(3)
	var fraction: Array = NpcfSaveCodec.as_int(3.5, "n")
	assert_bool(fraction[0]).is_false()
	assert_str(fraction[1]).is_equal("n: expected an integer")
	var text: Array = NpcfSaveCodec.as_int("3", "n")
	assert_bool(text[0]).is_false()
	assert_str(text[1]).is_equal("n: expected an integer")


func test_header() -> void:
	var w: NpcfWorld = _world(SEED)
	var data: Dictionary = NpcfSaveCodec.encode(w)
	assert_int(NpcfSaveCodec.last_error().length()).is_equal(0)
	assert_that(data["schema_version"]).is_equal(1)
	var pack_info: Dictionary = data["pack"]
	assert_str(pack_info["namespace"]).is_equal("toy")
	assert_str(data["seed"]).is_equal("7")
	assert_that(data["tick"]).is_equal(0)
	assert_int(NpcfSaveCodec.seed_of(data)).is_equal(SEED)
	w.dispose()


func test_incompatible_headers() -> void:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	var scenario: NpcfScenarioDef = ToyFixture.basic()
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, scenario, SEED)
	var base: Dictionary = NpcfSaveCodec.encode(w)
	w.dispose()

	var schema: Dictionary = base.duplicate(true)
	schema["schema_version"] = 2
	assert_str(NpcfSaveCodec.check_compatible(schema, pack, scenario)).is_equal(
		"save schema 2 is not supported (expected 1)")

	var wrong_ns: Dictionary = base.duplicate(true)
	var ns_pack: Dictionary = wrong_ns["pack"]
	ns_pack["namespace"] = "zz"
	assert_str(NpcfSaveCodec.check_compatible(wrong_ns, pack, scenario)).is_equal(
		"save is for pack \"zz\", running pack is \"toy\"")

	var major: Dictionary = base.duplicate(true)
	var major_pack: Dictionary = major["pack"]
	major_pack["version"] = "9.0.0"
	assert_str(NpcfSaveCodec.check_compatible(major, pack, scenario)).is_equal(
		"save is for pack version 9.0.0, running version %s has a different major version" % pack.manifest.pack_version)

	var minor: Dictionary = base.duplicate(true)
	var minor_pack: Dictionary = minor["pack"]
	minor_pack["version"] = pack.manifest.pack_version
	assert_str(NpcfSaveCodec.check_compatible(minor, pack, scenario)).is_equal("")

	var other_scenario: Dictionary = base.duplicate(true)
	other_scenario["scenario"] = "toy.other"
	assert_str(NpcfSaveCodec.check_compatible(other_scenario, pack, scenario)).is_equal(
		"save is for scenario \"toy.other\", running scenario is \"%s\"" % scenario.id)


func test_same_seed_same_text() -> void:
	assert_str(_text_after(3, 300)).is_equal(_text_after(3, 300))


func test_restore_then_encode_is_identity() -> void:
	var a: NpcfWorld = _world(SEED)
	for _i: int in 300:
		a.step()
	var t1: String = NpcfSaveCodec.to_text(NpcfSaveCodec.encode(a))
	var saved: Dictionary = NpcfSaveCodec.parse(t1)
	assert_bool(saved.is_empty()).is_false()
	var b: NpcfWorld = _world(NpcfSaveCodec.seed_of(saved))
	assert_str(NpcfSaveCodec.restore(b, saved)).is_equal("")
	var t2: String = NpcfSaveCodec.to_text(NpcfSaveCodec.encode(b))
	assert_str(t2).is_equal(t1)
	a.dispose()
	b.dispose()


## Builds a saved state after 300 ticks, parsed back, for the edit-and-restore tests.
func _saved_state() -> Dictionary:
	var w: NpcfWorld = _world(SEED)
	for _i: int in 300:
		w.step()
	var data: Dictionary = NpcfSaveCodec.parse(NpcfSaveCodec.to_text(NpcfSaveCodec.encode(w)))
	w.dispose()
	return data


func test_rejects_unknown_fact() -> void:
	var data: Dictionary = _saved_state()
	var facts: Array = data["facts"]
	var first: Array = facts[0]
	var pairs: Array = first[1]
	pairs.append(["toy.not_a_fact", ["i", "1"]])
	var b: NpcfWorld = _world(SEED)
	assert_str(NpcfSaveCodec.restore(b, data)).is_equal("facts: unknown fact toy.not_a_fact")
	b.dispose()


func test_rejects_wrong_fact_type() -> void:
	var data: Dictionary = _saved_state()
	var facts: Array = data["facts"]
	var first: Array = facts[0]
	var subject: String = first[0]
	var pairs: Array = first[1]
	var pair: Array = pairs[0]
	var fact_id: String = pair[0]
	pair[1] = ["s", "not a number or flag"]
	var b: NpcfWorld = _world(SEED)
	assert_str(NpcfSaveCodec.restore(b, data)).is_equal("facts: %s/%s: wrong type" % [subject, fact_id])
	b.dispose()


func test_rejects_cast_mismatch() -> void:
	var data: Dictionary = _saved_state()
	var npcs: Array = data["npcs"]
	npcs.pop_back()
	var b: NpcfWorld = _world(SEED)
	assert_str(NpcfSaveCodec.restore(b, data)).is_equal("npcs: saved cast does not match the scenario")
	b.dispose()


func test_rejects_unknown_action() -> void:
	var data: Dictionary = _saved_state()
	var npcs: Array = data["npcs"]
	var first: Dictionary = npcs[0]
	var plan: Array = first["plan"]
	plan.append({"call_id": 1, "npc": first["id"], "action": "toy.nope", "args": [], "decision_tick": 0})
	var b: NpcfWorld = _world(SEED)
	var message: String = NpcfSaveCodec.restore(b, data)
	assert_str(message).contains("unknown action toy.nope")
	b.dispose()
