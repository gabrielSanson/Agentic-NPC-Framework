class_name NpcfExecutor
extends RefCounted
## Starts, advances, finishes and cancels actions (R9.3-R9.6).
## TODO(task 10): the start checks, per-tick advance, end and cleanup effects and plan chaining are
## not implemented yet. Every method below is a safe no-op or default until then.

const OK: StringName = &"ok"


func start(_world: NpcfWorld, _npc: StringName, _call: NpcfActionCall, _report: NpcfTickReport = null) -> StringName:
	return OK


func advance(_world: NpcfWorld, _report: NpcfTickReport = null) -> void:
	pass


func cancel(_world: NpcfWorld, _npc: StringName, _reason: StringName, _report: NpcfTickReport = null) -> void:
	pass


func finish(_world: NpcfWorld, _npc: StringName, _success: bool, _reason: StringName, _report: NpcfTickReport = null) -> void:
	pass


func on_finished(_world: NpcfWorld, _input: NpcfInput) -> void:
	pass


func on_move_failed(_world: NpcfWorld, _input: NpcfInput) -> void:
	pass


func start_plan(_world: NpcfWorld, _npc: StringName, _plan: NpcfPlan, _report: NpcfTickReport = null) -> StringName:
	return OK
