class_name NpcfDueEntry
extends RefCounted
## Why an NPC is due to decide, and when it became due.

var due_tick: int = 0
var reason: StringName = &""
var bypass: bool = false
var rule: StringName = &""
