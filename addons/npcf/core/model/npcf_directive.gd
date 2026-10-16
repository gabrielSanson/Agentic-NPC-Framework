class_name NpcfDirective
extends RefCounted
## A time-limited bias on one goal's utility for the NPCs it targets (design "3. Utility scoring").
## A directive targets either one NPC (`target_npc`) or every NPC matching its tag query.

var id: int = -1
## The Director rule or reaction rule that produced it.
var origin: StringName = &""
var target_tags_all: Array[StringName] = []
var target_tags_any: Array[StringName] = []
var target_tags_none: Array[StringName] = []
var target_npc: StringName = &""
var goal: StringName = &""
var priority: float = 0.0
var expires_tick: int = 0


## True when this directive applies to an NPC with the given ID and tags.
func targets(npc: StringName, tags: Array[StringName]) -> bool:
	if target_npc != &"":
		return target_npc == npc
	for t: StringName in target_tags_all:
		if not tags.has(t):
			return false
	if not target_tags_any.is_empty():
		var any: bool = false
		for t: StringName in target_tags_any:
			if tags.has(t):
				any = true
				break
		if not any:
			return false
	for t: StringName in target_tags_none:
		if tags.has(t):
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"id": id, "origin": String(origin), "target_npc": String(target_npc), "goal": String(goal),
		"priority": priority, "expires_tick": expires_tick, "tags_all": NpcfValueCodec.names(target_tags_all),
		"tags_any": NpcfValueCodec.names(target_tags_any), "tags_none": NpcfValueCodec.names(target_tags_none),
	}
