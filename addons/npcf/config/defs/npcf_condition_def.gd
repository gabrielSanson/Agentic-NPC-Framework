@tool
class_name NpcfConditionDef
extends Resource
## A condition evaluated on an NPC's view (beliefs and own state) or on ground truth at action start.

enum OpKind { FACT, NEED, TAG, AT_LOCATION, ALL, ANY, NOT, HOOK }
## Whose fact, tag or location is checked.
enum SubjectFrom { SELF, ARG, CURRENT_LOCATION, GLOBAL, PLAYER }
enum Compare { EQ, NE, LT, LE, GT, GE, EXISTS }

@export var op_kind: OpKind = OpKind.FACT
@export var subject_from: SubjectFrom = SubjectFrom.SELF
## Action argument naming the subject when subject_from is ARG.
@export var arg: StringName = &""
@export var fact: NpcfFactDef = null
@export var need: NpcfNeedDef = null
## Tag ID for TAG conditions.
@export var tag: StringName = &""
## AT_LOCATION: the location, or leave null and set location_tag.
@export var location: NpcfLocationDef = null
@export var location_tag: StringName = &""
@export var compare: Compare = Compare.EQ
## Compared value. Must match the fact's type (FACT) or be an int (NEED).
@export var value: Variant = null
## Beliefs below this confidence make a FACT condition false.
@export_range(0, 100) var min_confidence: int = 50
## Children of ALL, ANY and NOT (NOT uses the first child).
@export var children: Array[NpcfConditionDef] = []
## Script extending NpcfConditionHook, for HOOK conditions.
@export var hook: Script = null
## Arguments passed to the hook.
@export var hook_args: Dictionary[StringName, Variant] = {}
