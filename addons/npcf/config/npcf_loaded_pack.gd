class_name NpcfLoadedPack
extends RefCounted
## A validated pack: definitions by ID (framework definitions included), the ID registry, the
## location index and the pack folder.

var manifest: NpcfPackManifest = null
var pack_namespace: StringName = &""
var pack_dir: String = ""
var manifest_path: String = ""
var sim: NpcfSimConfig = null
var registry: NpcfIdRegistry = null
var facts: Dictionary[StringName, NpcfFactDef] = {}
var needs: Dictionary[StringName, NpcfNeedDef] = {}
var event_kinds: Dictionary[StringName, NpcfEventKindDef] = {}
var goals: Dictionary[StringName, NpcfGoalDef] = {}
var actions: Dictionary[StringName, NpcfActionDef] = {}
var archetypes: Dictionary[StringName, NpcfArchetypeDef] = {}
var personalities: Dictionary[StringName, NpcfPersonalityDef] = {}
var characters: Dictionary[StringName, NpcfCharacterDef] = {}
var locations: Dictionary[StringName, NpcfLocationDef] = {}
var schedules: Dictionary[StringName, NpcfScheduleDef] = {}
var reactions: Array[NpcfReactionRuleDef] = []
var invariants: Array[NpcfInvariantDef] = []
## Never null after load: an empty NpcfSocialDef when the manifest has none.
var social: NpcfSocialDef = null
var rel_dims: Dictionary[StringName, NpcfRelDimDef] = {}
## Never null after load.
var rumor_rules: NpcfRumorRules = null
## Never null after load: an empty NpcfDirectorDef when the manifest has none.
var director: NpcfDirectorDef = null
var macros: Dictionary[StringName, NpcfMacroVarDef] = {}
var location_index: NpcfLocationIndex = null


func fact(id: StringName) -> NpcfFactDef:
	return facts.get(id)


func need(id: StringName) -> NpcfNeedDef:
	return needs.get(id)


func action(id: StringName) -> NpcfActionDef:
	return actions.get(id)


func goal(id: StringName) -> NpcfGoalDef:
	return goals.get(id)


func event_kind(id: StringName) -> NpcfEventKindDef:
	return event_kinds.get(id)


func location(id: StringName) -> NpcfLocationDef:
	return locations.get(id)


## JSON-friendly dictionary of one resolved character (the CLI `resolve` command).
func to_debug_dict(character: NpcfResolvedCharacter) -> Dictionary:
	var d: Dictionary = character.to_debug_dict()
	d["pack"] = {"namespace": String(pack_namespace), "version": manifest.pack_version if manifest != null else ""}
	return d
