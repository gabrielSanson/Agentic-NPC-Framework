extends GdUnitTestSuite
## Every configuration Resource class can be saved as .tres and reloaded with its fields intact.

const DIR: String = "user://npcf_test_defs"

var _classes: Array[GDScript] = [
	NpcfPackManifest, NpcfSimConfig, NpcfFactDef, NpcfFieldDef, NpcfNeedDef, NpcfEventKindDef,
	NpcfFactTemplate, NpcfConsiderationDef, NpcfGoalDef, NpcfConditionDef, NpcfEffectDef,
	NpcfActionDef, NpcfScriptDef, NpcfScriptStep, NpcfPlannerRef, NpcfArchetypeDef,
	NpcfPersonalityDef, NpcfCharacterDef, NpcfScenarioDef, NpcfCastEntry, NpcfFactSeed,
	NpcfRelSeed, NpcfInvariantDef, NpcfLocationDef, NpcfEdgeDef, NpcfLocationGraph,
	NpcfScheduleDef, NpcfScheduleEntry, NpcfReactionRuleDef,
]


func before() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func test_each_class_round_trips() -> void:
	for cls: GDScript in _classes:
		var res: Resource = cls.new()
		var changed: Array[String] = _fill(res)
		var path: String = DIR.path_join("%s.tres" % cls.get_global_name())
		assert_int(ResourceSaver.save(res, path)).override_failure_message("save %s" % path).is_equal(OK)
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_object(loaded).is_not_null()
		for prop: String in changed:
			assert_str(var_to_str(loaded.get(prop))).override_failure_message(
					"%s.%s changed on reload" % [cls.get_global_name(), prop]).is_equal(var_to_str(res.get(prop)))


func test_variant_export_keeps_type() -> void:
	var f: NpcfFactDef = NpcfFactDef.new()
	f.value_type = NpcfFactDef.ValueType.STRING_NAME
	f.default_value = &"toy.yard"
	var path: String = DIR.path_join("variant.tres")
	ResourceSaver.save(f, path)
	var loaded: NpcfFactDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(typeof(loaded.default_value)).is_equal(TYPE_STRING_NAME)
	assert_bool(loaded.accepts(loaded.default_value)).is_true()


## Sets every simple exported property to a non-default value. Returns the names it set.
func _fill(res: Resource) -> Array[String]:
	var changed: Array[String] = []
	for p: Dictionary in res.get_property_list():
		var usage: int = p["usage"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var prop: String = p["name"]
		var t: int = p["type"]
		var hint: int = p["hint"]
		match t:
			TYPE_BOOL:
				var current: bool = res.get(prop)
				res.set(prop, not current)
			TYPE_INT:
				res.set(prop, 1 if hint == PROPERTY_HINT_ENUM else 7)
			TYPE_FLOAT:
				res.set(prop, 0.25)
			TYPE_STRING:
				res.set(prop, "1.2.3")
			TYPE_STRING_NAME:
				res.set(prop, &"toy.example")
			TYPE_NIL:
				res.set(prop, &"toy.value")
			TYPE_PACKED_INT32_ARRAY:
				res.set(prop, PackedInt32Array([1, 3]))
			_:
				continue
		changed.append(prop)
	return changed
