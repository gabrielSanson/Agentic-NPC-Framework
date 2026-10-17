extends Node2D
## The bench scene: the toy room with npc_count NPCs cloned from the basic scenario's cast, run by the runtime at
## bench speed. The test drives the runtime one 60 fps frame at a time and times every frame that ran a tick, so
## each sample is one tick's step time. When bench_ticks ticks have run it prints median, p99, max and the capped
## frames, and quits when the user args include --quit-after-bench.

@export var manifest_path: String = "res://packs/toy/pack.tres"
@export var scenario_path: String = "res://packs/toy/scenarios/basic.tres"
@export var npc_count: int = 50
@export var bench_ticks: int = 1440
@export var world_seed: int = 7
@export var bench_speed: float = 16.0
@export var room_positions: Dictionary[StringName, Vector2] = {
	&"toy.home_a": Vector2(120, 120),
	&"toy.home_b": Vector2(120, 420),
	&"toy.yard": Vector2(420, 270),
	&"toy.workshop": Vector2(760, 270),
}

const FRAME_SECONDS: float = 1.0 / 60.0
const FRAMES_PER_PROCESS: int = 256
const NPC_SCENE: String = "res://samples/toy_room/toy_npc.tscn"
const RUNTIME_PATH: NodePath = ^"/root/Npcf"

var _npcf: NpcfRuntime = null
var _samples: Array[float] = []
var _ticks: int = 0
var _readout: Label = null
var _done: bool = false


func _ready() -> void:
	_npcf = get_node(RUNTIME_PATH) as NpcfRuntime
	var manifest: NpcfPackManifest = ResourceLoader.load(manifest_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	var scenario: NpcfScenarioDef = ResourceLoader.load(scenario_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	if manifest == null or scenario == null:
		push_error("npcf bench: cannot load %s or %s" % [manifest_path, scenario_path])
		get_tree().quit(1)
		return
	var population: NpcfBench.Population = NpcfBench.population(manifest, scenario, npc_count)
	_npcf.auto_process = false
	_npcf.sim_error.connect(func(message: String) -> void: push_error(message))
	if _npcf.start(population.manifest, population.scenario, world_seed, manifest.resource_path.get_base_dir()) != OK:
		get_tree().quit(1)
		return
	_npcf.set_speed(bench_speed)
	ToyRoom.build_rooms(self, manifest.location_graph, room_positions)
	var scene: PackedScene = load(NPC_SCENE) as PackedScene
	for id: StringName in _npcf.get_world().npc_ids:
		_spawn(scene, id)
	_readout = Label.new()
	_readout.position = Vector2(12, 8)
	add_child(_readout)


func _exit_tree() -> void:
	if _npcf != null:
		_npcf.stop()


func _process(_delta: float) -> void:
	if _done or not _npcf.is_running():
		return
	for _f: int in FRAMES_PER_PROCESS:
		var started: int = Time.get_ticks_usec()
		var steps: int = _npcf.advance_frame(FRAME_SECONDS)
		if steps > 0:
			_samples.append((Time.get_ticks_usec() - started) / 1000.0 / steps)
		_ticks += steps
		if _ticks >= bench_ticks:
			_finish()
			return
	_readout.text = "%d NPCs · tick %d / %d · median %.3f ms · p99 %.3f ms · capped %d" % [
		npc_count, _ticks, bench_ticks, _median(), _p99(), _npcf.capped_frames]


func _finish() -> void:
	_done = true
	_readout.text = "bench done: %d NPCs, %d ticks, median %.3f ms, p99 %.3f ms, max %.3f ms, capped %d" % [
		npc_count, _ticks, _median(), _p99(), _max(), _npcf.capped_frames]
	print(_readout.text)
	if OS.get_cmdline_user_args().has("--quit-after-bench"):
		get_tree().quit(0)


func _sorted() -> Array[float]:
	var sorted: Array[float] = _samples.duplicate()
	sorted.sort()
	return sorted


func _median() -> float:
	var sorted: Array[float] = _sorted()
	return NpcfBench.percentile(sorted, 0.5) if not sorted.is_empty() else 0.0


func _p99() -> float:
	var sorted: Array[float] = _sorted()
	return NpcfBench.percentile(sorted, 0.99) if not sorted.is_empty() else 0.0


func _max() -> float:
	var sorted: Array[float] = _sorted()
	return sorted.back() if not sorted.is_empty() else 0.0


func _spawn(scene: PackedScene, id: StringName) -> void:
	var inst: Node = scene.instantiate()
	if not inst is CharacterBody2D:
		push_error("npcf bench: toy_npc.tscn root is not a CharacterBody2D")
		return
	var body: CharacterBody2D = inst
	ToyRoom.agent_of(body).npc_id = id
	body.position = _npcf.anchor_position(_npcf.location_of(id))
	add_child(body)
