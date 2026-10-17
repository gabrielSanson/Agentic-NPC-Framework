class_name NpcfMemoryLog
extends RefCounted
## An NPC's capped episodic log (R7). Filled by delivery; never read by decisions.

var cap: int = 64
var records: Array[NpcfMemoryRecord] = []
var next_id: int = 1


## Adds a record (assigning its ID), then drops the lowest-salience record, oldest first among equals
## (lowest tick, then lowest ID), until size() <= cap. The new record itself may be the one dropped.
func append(record: NpcfMemoryRecord) -> void:
	record.id = next_id
	next_id += 1
	records.append(record)
	var limit: int = maxi(cap, 0)
	while records.size() > limit:
		records.remove_at(_weakest())


func size() -> int:
	return records.size()


## Index of the record with the smallest (salience, tick, id). The log must not be empty.
func _weakest() -> int:
	var best: int = 0
	for i: int in range(1, records.size()):
		if _less(records[i], records[best]):
			best = i
	return best


static func _less(a: NpcfMemoryRecord, b: NpcfMemoryRecord) -> bool:
	if a.salience != b.salience:
		return a.salience < b.salience
	if a.tick != b.tick:
		return a.tick < b.tick
	return a.id < b.id
