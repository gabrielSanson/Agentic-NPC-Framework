class_name NpcfOccupancy
extends RefCounted
## Which NPCs stand at each location, kept sorted so location queries need no scan of every NPC. Mirrors
## the fact npcf.at for NPCs: the effect applier moves an NPC whenever it writes that fact, and the world
## builder enters every NPC at setup. Only NPCs are indexed; the player is not.


## The sorted NPC IDs at one location. A wrapper, because typed collections cannot nest.
class Bucket extends RefCounted:
	var ids: Array[StringName] = []


var _buckets: Dictionary[StringName, Bucket] = {}


## Puts an NPC at a location when it has no earlier location (setup).
func enter(npc: StringName, location: StringName) -> void:
	_insert(npc, location)


## Moves an NPC from `from` to `to`. Removes it from `from` when it is there.
func move(npc: StringName, from: StringName, to: StringName) -> void:
	_remove(npc, from)
	_insert(npc, to)


## The NPC IDs at a location, sorted (a copy).
func at(location: StringName) -> Array[StringName]:
	var b: Bucket = _buckets.get(location)
	if b == null:
		return []
	return b.ids.duplicate()


func _insert(npc: StringName, location: StringName) -> void:
	var b: Bucket = _buckets.get(location)
	if b == null:
		b = Bucket.new()
		_buckets[location] = b
	var i: int = b.ids.bsearch_custom(npc, NpcfWorldState.name_less)
	if i < b.ids.size() and b.ids[i] == npc:
		return
	b.ids.insert(i, npc)


func _remove(npc: StringName, location: StringName) -> void:
	var b: Bucket = _buckets.get(location)
	if b == null:
		return
	var i: int = b.ids.bsearch_custom(npc, NpcfWorldState.name_less)
	if i < b.ids.size() and b.ids[i] == npc:
		b.ids.remove_at(i)
