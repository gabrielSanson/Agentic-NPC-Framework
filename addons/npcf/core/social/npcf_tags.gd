class_name NpcfTags
extends RefCounted
## Tag transitions (R11.2), phase 4. NPCs in ID order, transitions in pack order. A transition applies when
## the NPC has every requires_tags tag and its condition holds on the NPC's view; its add/remove become
## TAG_ADD/TAG_REMOVE changes applied through the applier (which emits npcf.tags_changed only for real changes).

## Shared empty argument map for condition checks (conditions never write to it).
var _no_args: Dictionary[StringName, Variant] = {}


## NPCs in ID order; transitions in pack order. Returns at once when the pack has none.
func evaluate_transitions(world: NpcfWorld) -> void:
	var transitions: Array[NpcfTagTransitionDef] = world.pack.social.tag_transitions
	if transitions.is_empty():
		return
	for id: StringName in world.npc_ids:
		var n: NpcfNpcState = world.npc(id)
		if n == null:
			continue
		for t: NpcfTagTransitionDef in transitions:
			if t == null:
				continue
			if not t.requires_tags.is_empty() and not _has_all(n.tags, t.requires_tags):
				continue
			if _is_noop(n.tags, t):
				continue
			if t.condition != null and not _holds(world, id, n, t.condition):
				continue
			var changes: Array[NpcfStateChange] = []
			for tag: StringName in t.add:
				changes.append(NpcfStateChange.tag_change(id, tag, true))
			for tag: StringName in t.remove:
				changes.append(NpcfStateChange.tag_change(id, tag, false))
			if not changes.is_empty():
				world.applier.apply(world, changes, -1)


## Whether a transition's condition holds for an NPC. A NEED condition reads only the NPC's own need, so it is
## compared directly; that gives the same answer as the view and saves building a view per NPC per tick.
func _holds(world: NpcfWorld, id: StringName, n: NpcfNpcState, c: NpcfConditionDef) -> bool:
	if c.op_kind == NpcfConditionDef.OpKind.NEED and c.need != null:
		return NpcfConditions.compare(n.needs.get(c.need.id, 0), c.compare, c.value)
	return NpcfConditions.check(world, world.view(id), c, _no_args, false)


static func _has_all(tags: Array[StringName], required: Array[StringName]) -> bool:
	for t: StringName in required:
		if not tags.has(t):
			return false
	return true


## True when every add is already present and every remove is already absent: the transition would change nothing,
## so its condition need not be checked.
static func _is_noop(tags: Array[StringName], t: NpcfTagTransitionDef) -> bool:
	for tag: StringName in t.add:
		if not tags.has(tag):
			return false
	for tag: StringName in t.remove:
		if tags.has(tag):
			return false
	return true
