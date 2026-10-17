@tool
class_name NpcfCharacterDef
extends Resource
## One NPC: archetype, personalities and its own overrides (R4.1). Null references and absent
## dictionary keys inherit from earlier layers.

## The NPC ID.
@export var id: StringName = &""
@export var display_name: String = ""
@export var archetype: NpcfArchetypeDef = null
@export var personalities: Array[NpcfPersonalityDef] = []
## Null inherits the archetype's schedule.
@export var schedule: NpcfScheduleDef = null
## Null inherits the archetype's planner.
@export var planner: NpcfPlannerRef = null
## Need ID -> start value.
@export var need_start: Dictionary[StringName, int] = {}
## Goal ID -> multiplier, multiplied with the personalities' multipliers.
@export var goal_multipliers: Dictionary[StringName, float] = {}
@export var tags_add: Array[StringName] = []
@export var extra_goals: Array[NpcfGoalDef] = []
## Appended to the personalities' voice text.
@export_multiline var voice: String = ""
## Appended to the personalities' speech_instruction.
@export_multiline var speech_instruction: String = ""
## A fixed voice of the speech server (Breeze voice_id). Empty = the dialogue default, else the server designs
## a voice from the instruction.
@export var speech_voice_id: String = ""
