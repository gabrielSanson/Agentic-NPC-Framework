class_name NpcfDialogueContext
extends RefCounted
## The read-only turn data handed to classifiers, choosers and generators. Framework and provider code only;
## pack code never gets one.

var world: NpcfWorld
var npc: StringName = &""
var player: StringName = &""
var player_text: String = ""
var view: NpcfNpcView
var dialogue: NpcfDialogueDef
## Set after classification (the intent that was used, after fallback).
var intent: StringName = &""
var confidence: float = 0.0
var outcome: NpcfRuleOutcome = null
var band: StringName = &""
var authored_line: String = ""
var presentation: Dictionary[StringName, StringName] = {}
var line_id: int = -1
## The request the LLM generator built for this turn, or null (set by the generator).
var last_request: NpcfDialogueRequest = null
