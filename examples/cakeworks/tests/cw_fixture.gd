class_name CwFixture
extends RefCounted
## Loads the cw pack and its smoke scenario for tests. Loads fresh copies (cache ignored) so a test
## never sees another test's changes. Fails loudly on any load error.

const MANIFEST: String = "res://packs/cw/pack.tres"
const STARTER: String = "res://packs/cw/scenarios/starter.tres"
const DEMO: String = "res://packs/cw/scenarios/demo.tres"


## A freshly loaded and validated cw pack.
static func load_pack() -> NpcfLoadedPack:
	var manifest: NpcfPackManifest = ResourceLoader.load(MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert(manifest != null, "could not load %s" % MANIFEST)
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(manifest)
	assert(result.ok, "cw pack has errors:\n" + result.format_errors())
	return result.pack


## The NPCs of the starter scenario, in cast order.
static func starter_npcs() -> Array[StringName]:
	return [&"cw.mira", &"cw.oskar", &"cw.juno"]


## The NPCs of the demo scenario, in cast order.
static func demo_npcs() -> Array[StringName]:
	return [&"cw.mira", &"cw.oskar", &"cw.tamsin", &"cw.rafi", &"cw.juno", &"cw.bea", &"cw.lev"]


## A freshly loaded copy of the starter scenario (three NPCs, headless acceptance).
static func starter() -> NpcfScenarioDef:
	return _load_scenario(STARTER)


## A freshly loaded copy of the demo scenario (seven NPCs).
static func demo() -> NpcfScenarioDef:
	return _load_scenario(DEMO)


static func _load_scenario(path: String) -> NpcfScenarioDef:
	var s: NpcfScenarioDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	assert(s != null, "could not load %s" % path)
	return s
