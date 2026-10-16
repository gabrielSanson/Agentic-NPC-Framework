@tool
class_name NpcfFactTemplate
extends Resource
## Maps an event to one belief: which fact, about which subject, with which value.

enum SubjectFrom { ACTOR_0, TARGET_0, LOCATION, GLOBAL, PAYLOAD }
enum ValueFrom { LITERAL, PAYLOAD, ACTOR_0, TARGET_0, LOCATION }

@export var fact: NpcfFactDef = null
@export var subject_from: SubjectFrom = SubjectFrom.ACTOR_0
## Payload field holding the subject when subject_from is PAYLOAD.
@export var subject_field: StringName = &""
@export var value_from: ValueFrom = ValueFrom.LITERAL
## The value when value_from is LITERAL. Must match the fact's type.
@export var value_literal: Variant = null
## Payload field holding the value when value_from is PAYLOAD.
@export var value_field: StringName = &""
