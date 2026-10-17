@tool
class_name NpcfPresentationRule
extends Resource
## Matches when every set field matches: intent (null = any), result (empty = any), condition on the NPC's view
## (null = always).

@export var intent: NpcfIntentDef = null
@export var result: StringName = &""
@export var condition: NpcfConditionDef = null
@export var answer: StringName = &""
