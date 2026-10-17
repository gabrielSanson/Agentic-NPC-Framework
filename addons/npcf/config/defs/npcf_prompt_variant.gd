@tool
class_name NpcfPromptVariant
extends Resource
## One situation text for a prompt. The first variant whose condition holds fills {{situation}}.

@export var id: StringName = &""
## Null = always holds.
@export var condition: NpcfConditionDef = null
@export_multiline var text: String = ""
