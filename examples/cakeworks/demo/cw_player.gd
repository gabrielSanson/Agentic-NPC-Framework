class_name CwPlayer
extends CharacterBody2D
## The player's body: WASD or arrow keys move it at 220 px/s. It carries a push-to-talk microphone and reports the
## NPC it faces (the dialogue addressee). Member of group npcf_player, which the voice players and dialogue read.

const SPEED: float = 220.0
const FACING_RANGE: float = 96.0
const FACING_DOT: float = 0.3

var facing_dir: Vector2 = Vector2.RIGHT
var _mic: NpcfMicCapture = null


func _ready() -> void:
	add_to_group(&"npcf_player")
	collision_layer = CwShip.BODY_LAYER
	collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	var visual: Polygon2D = Polygon2D.new()
	visual.color = Color(0.85, 0.9, 1.0, 1.0)
	visual.polygon = PackedVector2Array([Vector2(0, -10), Vector2(9, 8), Vector2(-9, 8)])
	add_child(visual)
	_mic = NpcfMicCapture.new()
	add_child(_mic)


## The microphone child (push-to-talk, transcripts).
func mic() -> NpcfMicCapture:
	return _mic


func _physics_process(_delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	# While the HUD's line edit has focus, typed letters are text, not movement.
	if not (get_viewport().gui_get_focus_owner() is LineEdit):
		dir = _input_dir()
	if dir != Vector2.ZERO:
		facing_dir = dir.normalized()
	velocity = dir.normalized() * SPEED
	move_and_slide()


## The NPC this body faces: the nearest NPC body within FACING_RANGE and in front of facing_dir. Empty if none.
func npcf_facing_npc() -> StringName:
	var best: StringName = &""
	var best_distance: float = FACING_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"cw_npc"):
		var body: CharacterBody2D = node as CharacterBody2D
		if body == null:
			continue
		var offset: Vector2 = body.position - position
		var distance: float = offset.length()
		if distance <= 0.0 or distance > best_distance:
			continue
		if facing_dir.dot(offset.normalized()) <= FACING_DOT:
			continue
		var agent: NpcfAgent2D = CwShip.agent_of(body)
		if agent != null:
			best = agent.npc_id
			best_distance = distance
	return best


func _input_dir() -> Vector2:
	var dir: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir
