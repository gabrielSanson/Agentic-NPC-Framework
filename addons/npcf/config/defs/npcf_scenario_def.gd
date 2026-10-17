@tool
class_name NpcfScenarioDef
extends Resource
## A starting situation: time, cast, seeded facts and relationships, player start.

@export var id: StringName = &""
@export var start_day: int = 0
@export_range(0, 1439) var start_minute: int = 480
@export var cast: Array[NpcfCastEntry] = []
@export var facts: Array[NpcfFactSeed] = []
@export var relationships: Array[NpcfRelSeed] = []
## Macro variable ID -> start value (Director, task 18).
@export var macro_start: Dictionary[StringName, float] = {}
@export var player_start: NpcfLocationDef = null
