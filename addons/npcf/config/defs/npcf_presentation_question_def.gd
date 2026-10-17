@tool
class_name NpcfPresentationQuestionDef
extends Resource
## A presentation choice made for every NPC line (emotion, gesture, voice delivery ...). Answers never touch
## simulation state; they travel with the line to the game (npc_line's `presentation` argument).

@export var id: StringName = &""
@export var description: String = ""
## The allowed answers, in order. options[0] is the default answer.
@export var options: Array[StringName] = []
## Option -> description for choice providers. Keys must be options.
@export var option_descriptions: Dictionary[StringName, String] = {}
## First matching rule gives the answer.
@export var rules: Array[NpcfPresentationRule] = []
