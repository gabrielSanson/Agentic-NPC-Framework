extends Node2D
## The toy room sample: the toy pack's locations as rooms, every cast NPC placed at its start location and driven
## by the Npcf runtime at sim_speed. A label per NPC shows its running action and a clock shows the game time.
## Run with the main scene (project setting run/main_scene).

@export var manifest_path: String = "res://packs/toy/pack.tres"
@export var scenario_path: String = "res://packs/toy/scenarios/basic.tres"
@export var world_seed: int = 7
@export var sim_speed: float = 8.0
@export var room_positions: Dictionary[StringName, Vector2] = {
	&"toy.home_a": Vector2(120, 120),
	&"toy.home_b": Vector2(120, 420),
	&"toy.yard": Vector2(420, 270),
	&"toy.workshop": Vector2(760, 270),
}

const NPC_SCENE: String = "res://samples/toy_room/toy_npc.tscn"
const RUNTIME_PATH: NodePath = ^"/root/Npcf"

var _bodies: Dictionary[StringName, Node2D] = {}
var _npcf: NpcfRuntime = null
var _labels: Dictionary[StringName, Label] = {}
var _clock: Label = null


func _ready() -> void:
	_npcf = get_node(RUNTIME_PATH) as NpcfRuntime
	var manifest: NpcfPackManifest = ResourceLoader.load(manifest_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	var scenario: NpcfScenarioDef = ResourceLoader.load(scenario_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	if manifest == null or scenario == null:
		push_error("npcf sample: cannot load %s or %s" % [manifest_path, scenario_path])
		return
	_npcf.sim_error.connect(func(message: String) -> void: push_error(message))
	if _npcf.start(manifest, scenario, world_seed) != OK:
		return
	_npcf.set_speed(sim_speed)
	ToyRoom.build_rooms(self, manifest.location_graph, room_positions)
	var scene: PackedScene = load(NPC_SCENE) as PackedScene
	for id: StringName in _npcf.get_world().npc_ids:
		_spawn(scene, id)
	_clock = Label.new()
	_clock.position = Vector2(12, 8)
	add_child(_clock)


func _exit_tree() -> void:
	if _npcf != null:
		_npcf.stop()


func _process(_delta: float) -> void:
	if not _npcf.is_running():
		return
	_clock.text = _npcf.get_world().clock.label()
	for id: StringName in _bodies:
		var trace: Dictionary = _npcf.trace(id)
		var running: String = trace.get("running", "")
		_labels[id].text = "%s: %s" % [id, running if running != "" else "idle"]
		_labels[id].position = _bodies[id].position + Vector2(-40, -36)


## Places an NPC body at its location's anchor, with its agent's npc_id set before it enters the tree.
func _spawn(scene: PackedScene, id: StringName) -> void:
	var inst: Node = scene.instantiate()
	if not inst is CharacterBody2D:
		push_error("npcf sample: toy_npc.tscn root is not a CharacterBody2D")
		return
	var body: CharacterBody2D = inst
	ToyRoom.agent_of(body).npc_id = id
	body.position = _npcf.anchor_position(_npcf.location_of(id))
	add_child(body)
	_bodies[id] = body
	var label: Label = Label.new()
	add_child(label)
	_labels[id] = label
