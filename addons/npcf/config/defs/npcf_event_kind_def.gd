@tool
class_name NpcfEventKindDef
extends Resource
## Declares an event kind: its payload, who learns of it and what they come to believe (R6.2).

@export var id: StringName = &""
@export var payload_fields: Array[NpcfFieldDef] = []
## 0..100. Used by memory (task 17) and rumors.
@export_range(0, 100) var salience: int = 50
## LOCAL: participants and perceivers. PUBLIC: also every other NPC. PARTICIPANTS_ONLY: only participants.
@export var visibility: NpcfEvent.Visibility = NpcfEvent.Visibility.LOCAL
## Confidence of beliefs received by broadcast (PUBLIC events not perceived directly).
@export_range(0, 100) var broadcast_confidence: int = 80
## Declarative mapping to beliefs. Leave empty when a mapper hook is set.
@export var beliefs: Array[NpcfFactTemplate] = []
## Script extending NpcfEventMapperHook; used instead of `beliefs` when set.
@export var mapper: Script = null
## Message key for memory records of this event.
@export var memory_key: StringName = &""
