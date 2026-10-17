extends GdUnitTestSuite
## NpcfProviderConfig: default timeouts per kind, check() messages, and that a saved config holds no key or secret
## property (C3a section 2.13).


func _valid() -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = &"llm"
	cfg.kind = NpcfProviderConfig.Kind.GENERATE
	cfg.adapter = &"openai_chat"
	cfg.base_url = "http://127.0.0.1:8080"
	cfg.use_for = [&"lines"]
	return cfg


func test_default_timeouts_per_kind_and_an_explicit_one() -> void:
	var expected: Array[int] = [8000, 2000, 10000, 10000]
	for k: int in 4:
		var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
		cfg.kind = k
		assert_int(cfg.effective_timeout_ms()).is_equal(expected[k])
	var set_cfg: NpcfProviderConfig = _valid()
	set_cfg.timeout_ms = 1234
	assert_int(set_cfg.effective_timeout_ms()).is_equal(1234)


func test_a_valid_config_has_no_errors() -> void:
	assert_int(_valid().check().size()).is_equal(0)


func test_empty_id_is_reported() -> void:
	var cfg: NpcfProviderConfig = _valid()
	cfg.id = &""
	var errs: PackedStringArray = cfg.check()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).is_equal("provider id is empty")


func test_bad_base_url_is_reported() -> void:
	var cfg: NpcfProviderConfig = _valid()
	cfg.base_url = "ftp://x"
	var errs: PackedStringArray = cfg.check()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).is_equal("base_url \"ftp://x\" is not http(s)://host[:port][/path]")


func test_use_for_outside_the_kind_is_reported() -> void:
	var cfg: NpcfProviderConfig = _valid()
	cfg.use_for = [&"intents"]
	var errs: PackedStringArray = cfg.check()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).is_equal("use_for \"intents\" is not allowed for kind GENERATE")


func test_key_env_must_be_an_environment_variable_name() -> void:
	var cfg: NpcfProviderConfig = _valid()
	cfg.key_env = "lower case"
	var errs: PackedStringArray = cfg.check()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).is_equal("key_env must be an environment variable name")


func test_saved_config_has_no_api_key_token_or_secret_property() -> void:
	var cfg: NpcfProviderConfig = _valid()
	cfg.key_env = "NPCF_TEST_KEY"
	var path: String = "user://provider_config_test.tres"
	assert_int(ResourceSaver.save(cfg, path)).is_equal(OK)
	var text: String = FileAccess.get_file_as_string(path)
	assert_bool(text.contains("key_env")).is_true()
	var secret: RegEx = RegEx.create_from_string("(api_key|token|secret)")
	for line: String in text.split("\n"):
		assert_bool(secret.search(line) == null).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
