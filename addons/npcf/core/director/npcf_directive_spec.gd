class_name NpcfDirectiveSpec
extends RefCounted
## A directive returned by a Director hook (task 18).

var tags_all: Array[StringName] = []
var tags_any: Array[StringName] = []
var tags_none: Array[StringName] = []
var goal: StringName = &""
var priority: float = 0.0
var duration_ticks: int = 0
