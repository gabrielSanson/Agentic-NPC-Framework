class_name NpcfSubjectFacts
extends RefCounted
## The facts stored for one subject, keyed by fact ID (wraps the inner dictionary because Godot's
## typed collections cannot nest).

var values: Dictionary[StringName, Variant] = {}
