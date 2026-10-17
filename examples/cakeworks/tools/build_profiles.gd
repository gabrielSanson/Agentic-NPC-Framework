extends SceneTree
## Builds the demo's provider profiles (demo/profiles/light.tres, full.tres, text_only.tres) in typed GDScript.
## Run from the example root, after tools/ci/sync_example.sh:
##   godot --headless --path examples/cakeworks -s res://tools/build_profiles.gd
## Keys never go in these files: a provider names the environment variable that holds its key (key_env).
## The .tres files are committed outputs. Change this script and run it again; never hand-edit them.

const OUT_DIR: String = "res://demo/profiles/"
const KEV_KEY_ENV: String = "KEV_API_KEY"
const GEMMA_URL: String = "http://127.0.0.1:8090"
const KEV_URL: String = "http://127.0.0.1:8009"
const PARAKEET_URL: String = "http://127.0.0.1:8010"
const BREEZE_URL: String = "http://127.0.0.1:8080"


func _init() -> void:
	var code: int = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# light: the default. Timeouts are the ones tuned for a laptop GPU.
	code = _fail_or(code, _save("light", [_gemma(12000), _kev(3000), _parakeet(15000), _breeze(20000)]))
	# full: the same four providers with the framework defaults for timeouts.
	code = _fail_or(code, _save("full", [_gemma(8000), _kev(2000), _parakeet(10000), _breeze(10000)]))
	# text_only: no voice, so Breeze and Parakeet are left out. Same timeouts as light.
	code = _fail_or(code, _save("text_only", [_gemma(12000), _kev(3000)]))
	quit(code)


func _fail_or(code: int, err: Error) -> int:
	return code if err == OK else 1


func _save(name: String, configs: Array[NpcfProviderConfig]) -> Error:
	var providers_set: NpcfProviderSet = NpcfProviderSet.new()
	for cfg: NpcfProviderConfig in configs:
		providers_set.providers.append(cfg)
	var path: String = OUT_DIR + name + ".tres"
	var err: Error = ResourceSaver.save(providers_set, path)
	if err != OK:
		push_error("build_profiles: cannot save %s (%s)" % [path, error_string(err)])
	else:
		print("build_profiles: wrote %s" % path)
	return err


static func _gemma(timeout_ms: int) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = &"gemma"
	cfg.kind = NpcfProviderConfig.Kind.GENERATE
	cfg.adapter = &"openai_chat"
	cfg.base_url = GEMMA_URL
	cfg.model = "gemma-4-12b"
	cfg.timeout_ms = timeout_ms
	cfg.use_for = [&"lines"]
	return cfg


static func _kev(timeout_ms: int) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = &"kev"
	cfg.kind = NpcfProviderConfig.Kind.CHOOSE
	cfg.adapter = &"kev_systemone"
	cfg.base_url = KEV_URL
	cfg.model = ""
	cfg.key_env = KEV_KEY_ENV
	cfg.timeout_ms = timeout_ms
	cfg.use_for = [&"intents", &"presentation"]
	return cfg


static func _parakeet(timeout_ms: int) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = &"parakeet"
	cfg.kind = NpcfProviderConfig.Kind.TRANSCRIBE
	cfg.adapter = &"openai_transcribe"
	cfg.base_url = PARAKEET_URL
	cfg.timeout_ms = timeout_ms
	cfg.use_for = [&"voice_in"]
	return cfg


## Breeze is non-commercial: the gateway refuses it unless npcf/providers/allow_non_commercial is set.
static func _breeze(timeout_ms: int) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = &"breeze"
	cfg.kind = NpcfProviderConfig.Kind.SPEAK
	cfg.adapter = &"breeze_speech"
	cfg.base_url = BREEZE_URL
	cfg.timeout_ms = timeout_ms
	cfg.license_use = NpcfProviderConfig.License.NON_COMMERCIAL
	cfg.use_for = [&"voice_out"]
	return cfg
