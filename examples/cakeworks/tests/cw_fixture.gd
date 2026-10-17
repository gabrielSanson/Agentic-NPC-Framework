class_name CwFixture
extends RefCounted
## Loads the cw pack and its smoke scenario for tests. Loads fresh copies (cache ignored) so a test
## never sees another test's changes. Fails loudly on any load error.

const MANIFEST: String = "res://packs/cw/pack.tres"
const SMOKE: String = "res://packs/cw/scenarios/smoke.tres"


## A freshly loaded and validated cw pack.
static func load_pack() -> NpcfLoadedPack:
	var manifest: NpcfPackManifest = ResourceLoader.load(MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert(manifest != null, "could not load %s" % MANIFEST)
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(manifest)
	assert(result.ok, "cw pack has errors:\n" + result.format_errors())
	return result.pack


## A freshly loaded copy of the smoke scenario.
static func smoke() -> NpcfScenarioDef:
	var s: NpcfScenarioDef = ResourceLoader.load(SMOKE, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	assert(s != null, "could not load %s" % SMOKE)
	return s
