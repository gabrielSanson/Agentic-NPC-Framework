@tool
class_name NpcfEffectDef
extends Resource
## One state change an action makes at start, end or cleanup (R9.1).

enum Kind { SET_FACT, ADD_FACT, NEED_DELTA, TAG_ADD, TAG_REMOVE, REL_DELTA, SHARE_BELIEFS, EMIT_EVENT, HOOK }

@export var kind: Kind = Kind.SET_FACT
@export var subject_from: NpcfConditionDef.SubjectFrom = NpcfConditionDef.SubjectFrom.SELF
## Action argument naming the subject when subject_from is ARG.
@export var arg: StringName = &""
@export var fact: NpcfFactDef = null
## SET_FACT value. Must match the fact's type.
@export var value: Variant = null
## ADD_FACT, NEED_DELTA and REL_DELTA amount.
@export var amount: int = 0
@export var need: NpcfNeedDef = null
@export var tag: StringName = &""
## Relationship dimension ID (REL_DELTA, task 17).
@export var dim: StringName = &""
## The other party of REL_DELTA, or the targets of EMIT_EVENT.
@export var to_from: NpcfConditionDef.SubjectFrom = NpcfConditionDef.SubjectFrom.ARG
@export var to_arg: StringName = &""
@export var event_kind: NpcfEventKindDef = null
## Script extending NpcfEffectHook, for HOOK effects.
@export var hook: Script = null
@export var hook_args: Dictionary[StringName, Variant] = {}
