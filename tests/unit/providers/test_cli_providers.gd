extends GdUnitTestSuite
## The `providers check` path without the process: a set saved to user:// loads, its gateway checks every provider
## against a fake server, and every provider is ready (C3a section 2.13). The CLI itself is not run in tests.

const SET_PATH: String = "user://providers_check_test.tres"

var _server: FakeHttpServer = null


func after_test() -> void:
	if _server != null:
		_server.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SET_PATH))


func test_a_saved_set_checks_every_provider_ready() -> void:
	_server = FakeHttpServer.new()
	assert_int(_server.start()).is_equal(OK)
	_server.json_route("GET /v1/models", 200, {"data": []})
	var cfg: NpcfProviderConfig = ProviderFixture.chat_config(&"llm", _server.url())
	var providers: Array[NpcfProviderConfig] = [cfg]
	var providers_set: NpcfProviderSet = NpcfProviderSet.new()
	providers_set.providers = providers
	assert_int(ResourceSaver.save(providers_set, SET_PATH)).is_equal(OK)
	var loaded: NpcfProviderSet = ResourceLoader.load(SET_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfProviderSet
	assert_object(loaded).is_not_null()
	var gw: NpcfProviderGateway = auto_free(NpcfProviderGateway.new())
	for loaded_cfg: NpcfProviderConfig in loaded.providers:
		gw.add_provider(loaded_cfg)
	gw.check_all_blocking(3000, _server.poll)
	assert_bool(gw.is_ready(&"llm")).is_true()
	gw.close()
