@tool
class_name NpcfPromptTemplate
extends Resource
## Builds the LLM messages for one NPC (R13.5). {{name}} placeholders must be declared macros; {{situation}} is
## built in and filled with the first variant whose condition holds (empty when none holds).

@export_multiline var system_text: String = ""
@export_multiline var scenario_text: String = ""
@export var variants: Array[NpcfPromptVariant] = []
@export var macros: Array[NpcfPromptMacro] = []
