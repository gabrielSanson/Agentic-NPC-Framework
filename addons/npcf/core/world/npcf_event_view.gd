class_name NpcfEventView
extends RefCounted
## Read-only view of a committed event, for mapper hooks and perception adapters.

var _event: NpcfEvent


func _init(event: NpcfEvent) -> void:
	_event = event


func id() -> int:
	return _event.id


func tick() -> int:
	return _event.tick


func kind() -> StringName:
	return _event.kind


func actors() -> Array[StringName]:
	return _event.actors.duplicate()


func targets() -> Array[StringName]:
	return _event.targets.duplicate()


func location() -> StringName:
	return _event.location


func payload_value(field: StringName, default: Variant = null) -> Variant:
	return _event.payload.get(field, default)


func payload() -> Dictionary[StringName, Variant]:
	return _event.payload.duplicate()


func visibility() -> int:
	return _event.visibility


func is_participant(entity: StringName) -> bool:
	return _event.actors.has(entity) or _event.targets.has(entity)
