@tool
class_name NpcfTagQuery
extends Resource
## Which NPCs a Director directive targets, by their tags: all of tags_all, any of tags_any (when given), none of tags_none.

@export var tags_all: Array[StringName] = []
@export var tags_any: Array[StringName] = []
@export var tags_none: Array[StringName] = []
