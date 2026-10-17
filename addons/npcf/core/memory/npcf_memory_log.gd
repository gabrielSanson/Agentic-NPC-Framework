class_name NpcfMemoryLog
extends RefCounted
## An NPC's capped episodic log (R7). Filled by delivery in task 17; never read by decisions.

var cap: int = 64
var records: Array[NpcfMemoryRecord] = []


func size() -> int:
	return records.size()
