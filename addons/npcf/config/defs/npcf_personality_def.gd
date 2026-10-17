@tool
class_name NpcfPersonalityDef
extends Resource
## A trait layer: multipliers on goal and action scores, tags and a voice description (R4.5).

@export var id: StringName = &""
## Goal ID -> multiplier 0..3.
@export var goal_multipliers: Dictionary[StringName, float] = {}
## Action ID -> multiplier 0..3.
@export var action_multipliers: Dictionary[StringName, float] = {}
@export var tags_add: Array[StringName] = []
## Persona text for dialogue, at most 300 characters.
@export_multiline var voice: String = ""
## How this trait sounds, for text-to-speech voice design (for example "Low, slow, slightly hoarse voice").
## Joined with the other layers' speech text. Not used in prompts (that is `voice`).
@export_multiline var speech_instruction: String = ""
