class_name NpcfActionCallView
extends RefCounted
## Read-only view of a running action call, for resolver hooks and presentation adapters.

var _call: NpcfActionCall
var _def: NpcfActionDef


func _init(p_call: NpcfActionCall, def: NpcfActionDef) -> void:
	_call = p_call
	_def = def


func call_id() -> int:
	return _call.call_id


func npc() -> StringName:
	return _call.npc


func action() -> StringName:
	return _call.action


func arg(name: StringName, default: Variant = null) -> Variant:
	return _call.args.get(name, default)


func args() -> Dictionary[StringName, Variant]:
	return _call.args.duplicate()


func duration_ticks() -> int:
	return _def.duration_ticks if _def != null else 1


func presentation_cue() -> StringName:
	return _def.presentation_cue if _def != null else &""
