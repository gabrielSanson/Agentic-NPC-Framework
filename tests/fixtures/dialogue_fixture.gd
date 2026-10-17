class_name DialogueFixture
extends RefCounted
## Loads the toy pack with its own copy of the dialogue. Resources loaded through the cache are shared by every
## test, so a test that changes an intent, a line set or a hook must load a fresh copy. Fails loudly on load errors.

const DIALOGUE: String = "res://packs/toy/dialogue/dialogue.tres"


## A freshly loaded and validated toy pack whose dialogue is a fresh copy.
static func load_pack() -> NpcfLoadedPack:
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert(manifest != null, "could not load %s" % ToyFixture.MANIFEST)
	manifest.dialogue = fresh_dialogue()
	var result: NpcfLoadResult = NpcfPackLoader.new().load_pack(manifest)
	assert(result.ok, "toy pack has errors:\n" + result.format_errors())
	return result.pack


## A freshly loaded copy of the toy dialogue (its intents, outcomes and line sets are fresh too).
static func fresh_dialogue() -> NpcfDialogueDef:
	var d: NpcfDialogueDef = ResourceLoader.load(DIALOGUE, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfDialogueDef
	assert(d != null, "could not load %s" % DIALOGUE)
	return d
