extends GdUnitTestSuite


func test_valid_ids() -> void:
	assert_bool(NpcfIds.is_valid(&"toy.rest")).is_true()
	assert_bool(NpcfIds.is_valid(&"toy.mem.helped")).is_true()
	assert_bool(NpcfIds.is_valid(&"npcf.at")).is_true()


func test_invalid_ids() -> void:
	assert_bool(NpcfIds.is_valid(&"Toy.rest")).is_false()
	assert_bool(NpcfIds.is_valid(&"rest")).is_false()
	assert_bool(NpcfIds.is_valid(&"toy.")).is_false()
	assert_bool(NpcfIds.is_valid(&"1toy.rest")).is_false()
	assert_bool(NpcfIds.is_valid(&"toy.Rest")).is_false()


func test_namespace_of() -> void:
	assert_str(String(NpcfIds.namespace_of(&"toy.rest"))).is_equal("toy")
	assert_str(String(NpcfIds.namespace_of(&"rest"))).is_equal("")


func test_check_pack_id() -> void:
	assert_str(NpcfIds.check_pack_id(&"toy.rest", &"toy")).is_empty()
	assert_str(NpcfIds.check_pack_id(&"npcf.rest", &"toy")).contains("reserved npcf namespace")
	assert_str(NpcfIds.check_pack_id(&"cw.rest", &"toy")).contains("must start with the pack namespace")
	assert_str(NpcfIds.check_pack_id(&"rest", &"toy")).contains("does not match")
	assert_str(NpcfIds.check_pack_id(&"", &"toy")).contains("empty")


func test_registry_duplicate() -> void:
	var reg: NpcfIdRegistry = NpcfIdRegistry.new()
	assert_object(reg.register(&"goal", &"toy.rest", "res://a.tres")).is_null()
	assert_object(reg.register(&"action", &"toy.rest", "res://b.tres")).is_null()
	var dup: NpcfConfigError = reg.register(&"goal", &"toy.rest", "res://c.tres")
	assert_object(dup).is_not_null()
	assert_str(dup.format()).is_equal("res://c.tres: id: duplicate goal ID \"toy.rest\" (already defined in res://a.tres) (hint: give each goal a unique ID)")


func test_registry_kind_mismatch() -> void:
	var reg: NpcfIdRegistry = NpcfIdRegistry.new()
	reg.register(&"need", &"toy.energy", "res://n.tres")
	assert_object(reg.require(&"need", &"toy.energy", "res://x.tres")).is_null()
	var wrong: NpcfConfigError = reg.require(&"action", &"toy.energy", "res://x.tres", "candidate_actions[0]")
	assert_str(wrong.format()).is_equal("res://x.tres: candidate_actions[0]: \"toy.energy\" is a need, expected a action (hint: reference a action here)")
	var unknown: NpcfConfigError = reg.require(&"goal", &"toy.nope", "res://x.tres", "goal")
	assert_str(unknown.reason).is_equal("unknown goal \"toy.nope\"")


func test_config_error_format() -> void:
	var e: NpcfConfigError = NpcfConfigError.make("res://packs/toy/characters/ana.tres",
			"personalities[1].goal_multipliers[\"toy.rest\"]", "4.0 is outside 0.0..3.0",
			"lower the multiplier or split it across two personalities")
	assert_str(e.format()).is_equal("res://packs/toy/characters/ana.tres: personalities[1].goal_multipliers[\"toy.rest\"]: 4.0 is outside 0.0..3.0 (hint: lower the multiplier or split it across two personalities)")
