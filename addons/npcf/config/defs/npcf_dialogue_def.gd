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
## Archetype ID -> prompt template. NPCs whose archetype has no entry use default_template.
@export var templates: Dictionary[StringName, NpcfPromptTemplate] = {}
@export var default_template: NpcfPromptTemplate = null
@export var lore: NpcfLoreRules = null
@export var llm: NpcfLlmConfig = null
## Memory message key -> text with {actors} {targets} {location} and {<payload field>} placeholders.
@export var memory_texts: Dictionary[StringName, String] = {}
@export var max_prompt_facts: int = 8
@export var presentation: Array[NpcfPresentationQuestionDef] = []
@export var last_talk_window_ticks: int = 30
## Speech instruction for NPCs whose layers give none.
@export_multiline var default_speech_instruction: String = ""
## voice_id for NPCs that set none. Empty = none.
@export var default_speech_voice_id: String = ""
## The presentation question whose answer shapes the delivery (for example an emotion question). Empty = none.
@export var delivery_question: StringName = &""
## Answer of delivery_question -> text appended to the speech instruction (for example "Clipped and irritated.").
@export var delivery_instructions: Dictionary[StringName, String] = {}
