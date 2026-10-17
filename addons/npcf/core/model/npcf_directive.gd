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


## Save form: every field, with the same keys as to_dict (see NpcfSaveCodec for the value tags).
func to_save() -> Dictionary:
	return to_dict()


## Reads a directive written by to_save.
static func from_save(r: NpcfSaveCodec.Reader, d: Variant, path: String) -> NpcfDirective:
	var n: NpcfDirective = NpcfDirective.new()
	n.id = r.int_at(d, "id", path)
	n.origin = r.name_at(d, "origin", path)
	n.target_npc = r.name_at(d, "target_npc", path)
	n.goal = r.name_at(d, "goal", path)
	n.priority = r.float_at(d, "priority", path)
	n.expires_tick = r.int_at(d, "expires_tick", path)
	n.target_tags_all = r.names_at(d, "tags_all", path)
	n.target_tags_any = r.names_at(d, "tags_any", path)
	n.target_tags_none = r.names_at(d, "tags_none", path)
	return n
