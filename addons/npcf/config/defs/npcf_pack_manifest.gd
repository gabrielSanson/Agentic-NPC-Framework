@tool
class_name NpcfPackManifest
extends Resource
## The root of a policy pack: its namespace, versions and every definition it contributes (R2.1).

@export var pack_namespace: StringName = &""
@export var pack_version: String = "0.1.0"
## The pack works with framework versions in framework_min (inclusive) .. framework_max_exclusive.
@export var framework_min: String = "0.2.0"
@export var framework_max_exclusive: String = "0.3.0"
@export var facts: Array[NpcfFactDef] = []
@export var needs: Array[NpcfNeedDef] = []
@export var event_kinds: Array[NpcfEventKindDef] = []
@export var goals: Array[NpcfGoalDef] = []
@export var actions: Array[NpcfActionDef] = []
@export var archetypes: Array[NpcfArchetypeDef] = []
@export var personalities: Array[NpcfPersonalityDef] = []
@export var characters: Array[NpcfCharacterDef] = []
@export var location_graph: NpcfLocationGraph = null
@export var schedules: Array[NpcfScheduleDef] = []
@export var reactions: Array[NpcfReactionRuleDef] = []
@export var invariants: Array[NpcfInvariantDef] = []
@export var sim: NpcfSimConfig = null
