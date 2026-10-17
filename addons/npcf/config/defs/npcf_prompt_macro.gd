@tool
class_name NpcfPromptMacro
extends Resource
## A named value for prompt templates. Every value comes from the NPC's own view, the memory log or the rule outcome.

enum Source { NPC_NAME, PERSONA, LOCATION_NAME, TIME_OF_DAY, NEED_BAND, FACT, RELATIONSHIP_BAND, RULE_OUTCOME, MEMORIES, FACTS, ACTIONS }
enum SubjectFrom { SELF, PLAYER, LOCATION }

## Lowercase letters, digits and underscores; not "situation".
@export var name: StringName = &""
@export var source: Source = Source.NPC_NAME
## FACT only.
@export var fact: NpcfFactDef = null
## FACT only: whose fact is read.
@export var subject_from: SubjectFrom = SubjectFrom.SELF
## NEED_BAND only.
@export var need: NpcfNeedDef = null
## RELATIONSHIP_BAND only (toward the player).
@export var dim: NpcfRelDimDef = null
