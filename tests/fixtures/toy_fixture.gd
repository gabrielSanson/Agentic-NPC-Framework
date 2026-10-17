class_name ToyFixture
extends RefCounted
## Loads the toy pack and its basic scenario for tests. Loads fresh copies (cache ignored) so a test
## may change its own pack without affecting the next test. Fails loudly on any load error.

const MANIFEST: String = "res://packs/toy/pack.tres"
const BASIC: String = "res://packs/toy/scenarios/basic.tres"


## A freshly loaded and validated toy pack.
static func load_pack() -> NpcfLoadedPack:
	var manifest: NpcfPackManifest = ResourceLoader.load(MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert(manifest != null, "could not load %s" % MANIFEST)
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(manifest)
	assert(result.ok, "toy pack has errors:\n" + result.format_errors())
	return result.pack


## A freshly loaded copy of the basic scenario.
static func basic() -> NpcfScenarioDef:
	var s: NpcfScenarioDef = ResourceLoader.load(BASIC, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	assert(s != null, "could not load %s" % BASIC)
	return s
