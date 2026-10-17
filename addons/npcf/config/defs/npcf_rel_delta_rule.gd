@tool
class_name NpcfRelDeltaRule
extends Resource
## Changes a relationship when an event is delivered (phase 6).

enum Role { ACTOR_0, TARGET_0, WITNESS }

@export var event_kind: NpcfEventKindDef = null
## Who holds the relationship. WITNESS means every recipient that witnessed the event.
@export var from_role: Role = Role.WITNESS
## Toward whom. ACTOR_0 or TARGET_0 only.
@export var to_role: Role = Role.ACTOR_0
@export var dim: NpcfRelDimDef = null
@export var delta: int = 0
