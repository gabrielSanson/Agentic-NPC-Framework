@tool
class_name NpcfDialogueDef
extends Resource
## A pack's dialogue rules (R13): intents, rule outcomes, authored lines, presentation questions and, in the LLM
## batch, prompt templates.

@export var intents: Array[NpcfIntentDef] = []
## Must also be listed in intents.
@export var fallback_intent: NpcfIntentDef = null
@export_range(0.0, 1.0) var confidence_threshold: float = 0.34
@export var lines: Array[NpcfDialogueLineSet] = []
## Used when no line set matches. Must not be empty.
@export var default_lines: PackedStringArray = []
## The relationship dimension (NPC toward the player) whose band selects authored lines.
@export var band_dim: NpcfRelDimDef = null
## Memory message key -> text with {actors} {targets} {location} and {<payload field>} placeholders.
@export var memory_texts: Dictionary[StringName, String] = {}
@export var presentation: Array[NpcfPresentationQuestionDef] = []
@export var last_talk_window_ticks: int = 30
