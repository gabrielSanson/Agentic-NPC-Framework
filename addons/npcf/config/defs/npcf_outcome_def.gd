@tool
class_name NpcfOutcomeDef
extends Resource
## A declarative rule outcome (R13.3).

enum RevealSubject { SELF, PLAYER, LOCATION }

@export var result: StringName = &""
## Relationship dimension ID -> delta, applied to the NPC's relationship toward the player.
@export var rel_deltas: Dictionary[StringName, int] = {}
@export var reveal: Array[NpcfFactDef] = []
@export var reveal_subject: RevealSubject = RevealSubject.SELF
