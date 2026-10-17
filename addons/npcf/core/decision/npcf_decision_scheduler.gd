class_name NpcfDecisionScheduler
extends RefCounted
## Decides which NPCs decide on a tick: periodic decisions spread by phase, and triggered ones
## marked due by events (design "3. Utility scoring").
## TODO(task 13): phases, due marking and capped selection are not implemented yet. Until then no
## NPC is ever due.


func init_npc(_world: NpcfWorld, _npc: StringName) -> void:
	pass


func mark_due(_world: NpcfWorld, _npc: StringName, _reason: StringName, _bypass: bool, _rule: StringName = &"") -> void:
	pass


func take_due(_world: NpcfWorld, _cap: int) -> Array[StringName]:
	return []


func last_taken(_npc: StringName) -> NpcfDueEntry:
	return NpcfDueEntry.new()
