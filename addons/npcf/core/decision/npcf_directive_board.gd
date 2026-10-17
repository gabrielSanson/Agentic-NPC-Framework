class_name NpcfDirectiveBoard
extends RefCounted
## Active directives: time-limited utility biases for the NPCs they target (design "3. Utility
## scoring"). Directives come from the Director (task 18) and from reactions (task 17).

var _items: Array[NpcfDirective] = []
var _next_id: int = 1


## Stores a directive and assigns its ID.
func add(d: NpcfDirective) -> void:
	d.id = _next_id
	_next_id += 1
	_items.append(d)


## The highest priority among directives that target this NPC and this goal, or 0.0.
func max_priority(npc: StringName, tags: Array[StringName], goal: StringName) -> float:
	var best: float = 0.0
	for d: NpcfDirective in _items:
		if d.goal == goal and d.priority > best and d.targets(npc, tags):
			best = d.priority
	return best


## Stored directives in order, for saves.
func export_items() -> Array[NpcfDirective]:
	return _items.duplicate()


## The next directive ID, for saves.
func export_next_id() -> int:
	return _next_id


## Replaces the board with saved state (IDs and order kept).
func restore(next_id: int, items: Array[NpcfDirective]) -> void:
	_next_id = next_id
	_items = items


## Drops directives whose expiry tick has passed.
func expire(tick: int) -> void:
	var kept: Array[NpcfDirective] = []
	for d: NpcfDirective in _items:
		if d.expires_tick > tick:
			kept.append(d)
	_items = kept


func active() -> Array[NpcfDirective]:
	return _items.duplicate()
