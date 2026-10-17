class_name NpcfNavMover2D
extends Node
## Walks an embodied NPC's body to the anchor of the location it is heading for: around obstacles through a
## NavigationAgent2D child when use_navigation is on, in a straight line otherwise. It never reports arrival;
## the location area does. A target that navigation cannot reach is reported as a failed move.

@export var speed: float = 120.0
@export var use_navigation: bool = true
@export var arrive_distance: float = 4.0

var _call_id: int = -1
var _target: Vector2 = Vector2.ZERO
var _walking: bool = false
var _path_checked: bool = false
var _nav: NavigationAgent2D = null


func _ready() -> void:
	for child: Node in get_children():
		if child is NavigationAgent2D:
			var nav: NavigationAgent2D = child
			_nav = nav
			nav.path_changed.connect(_on_path_changed)
			break


## Starts walking toward the last location of `path`, for the call `call_id`.
func walk(call_id: int, path: Array[StringName]) -> void:
	var agent: NpcfAgent2D = _agent()
	var rt: NpcfRuntime = agent.runtime() if agent != null else null
	if path.is_empty() or rt == null:
		return
	_call_id = call_id
	_target = rt.anchor_position(path[path.size() - 1])
	_walking = true
	_path_checked = false
	if _nav != null:
		_nav.target_position = _target


## Stops walking and zeroes the body's velocity.
func halt() -> void:
	_walking = false
	var body: CharacterBody2D = _body()
	if body != null:
		body.velocity = Vector2.ZERO


func is_walking() -> bool:
	return _walking


func _physics_process(_delta: float) -> void:
	if not _walking:
		return
	var body: CharacterBody2D = _body()
	if body == null:
		return
	var here: Vector2 = body.global_position
	if here.distance_to(_target) <= arrive_distance:
		halt()
		return
	var next: Vector2 = _target
	if use_navigation and _nav != null:
		next = _nav.get_next_path_position()
	body.velocity = (next - here).normalized() * speed
	body.move_and_slide()


func _on_path_changed() -> void:
	if not _walking or _path_checked or not use_navigation or _nav == null:
		return
	_path_checked = true
	if _nav.is_target_reachable():
		return
	var agent: NpcfAgent2D = _agent()
	var rt: NpcfRuntime = agent.runtime() if agent != null else null
	if rt != null:
		rt.report_move_failed(agent.npc_id, _call_id, &"unreachable")
	halt()


func _agent() -> NpcfAgent2D:
	var p: Node = get_parent()
	if p is NpcfAgent2D:
		var a: NpcfAgent2D = p
		return a
	return null


func _body() -> CharacterBody2D:
	var a: NpcfAgent2D = _agent()
	return a.body() if a != null else null
