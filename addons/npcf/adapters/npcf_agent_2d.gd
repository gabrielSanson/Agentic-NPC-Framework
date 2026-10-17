class_name NpcfAgent2D
extends Node
## The link between one NPC and its CharacterBody2D. Child of the body. Registers the body with the runtime
## on ready and unregisters it on exit. The game plays actions from the play_action signal and may finish them
## itself through finish_action when game_finishes_actions is set.

signal play_action(call_id: int, action: StringName, cue: StringName, duration_ticks: int)
signal action_cancelled(call_id: int)

@export var npc_id: StringName
## When true, the game reports completion with finish_action; otherwise an embodied action ends by duration.
@export var game_finishes_actions: bool = false
@export var runtime_path: NodePath = ^"/root/Npcf"


## The CharacterBody2D this agent belongs to, or null when the parent is not one.
func body() -> CharacterBody2D:
	var p: Node = get_parent()
	if p is CharacterBody2D:
		var b: CharacterBody2D = p
		return b
	return null


## The first NpcfNavMover2D child, or null.
func mover() -> NpcfNavMover2D:
	for child: Node in get_children():
		if child is NpcfNavMover2D:
			var m: NpcfNavMover2D = child
			return m
	return null


## The NpcfAreaPerception2D under the agent or under its body (the sample puts it under the body), or null.
func perception() -> NpcfAreaPerception2D:
	var found: NpcfAreaPerception2D = _first_perception(self)
	if found == null and body() != null:
		found = _first_perception(body())
	return found


func _first_perception(parent: Node) -> NpcfAreaPerception2D:
	for child: Node in parent.get_children():
		if child is NpcfAreaPerception2D:
			var p: NpcfAreaPerception2D = child
			return p
	return null


## The runtime at runtime_path, or null when there is none.
func runtime() -> NpcfRuntime:
	var node: Node = get_node_or_null(runtime_path)
	if node is NpcfRuntime:
		var rt: NpcfRuntime = node
		return rt
	return null


func finish_action(call_id: int, success: bool = true, reason: StringName = &"") -> void:
	var rt: NpcfRuntime = runtime()
	if rt != null:
		rt.finish_action(npc_id, call_id, success, reason)


func _ready() -> void:
	var rt: NpcfRuntime = runtime()
	if rt != null:
		rt.register_npc_node(npc_id, self)


func _exit_tree() -> void:
	var rt: NpcfRuntime = runtime()
	if rt != null:
		rt.unregister_npc_node(npc_id)
