class_name CwDemoMain
extends Node2D
## The CakeWorks playable demo. Starts the runtime on the demo scenario (seven NPCs), builds the ship in code,
## spawns the NPCs and the player, and adds the HUD. Options: the exports, then the user args after `--`:
##   --profile=<light|full|text_only>  --seed=<n>  --allow-non-commercial  --no-models
## Models are off when --no-models is set or use_models is false (the headless tests use that).

const PROFILE_DIR: String = "res://demo/profiles/"
const MANIFEST_PATH: String = "res://packs/cw/pack.tres"
const SCENARIO_PATH: String = "res://packs/cw/scenarios/demo.tres"
const NPC_SCENE: String = "res://demo/cw_npc.tscn"
const RUNTIME_PATH: NodePath = ^"/root/Npcf"
const PLAYER_START: StringName = &"cw.lounge"
const PROFILES: PackedStringArray = ["light", "full", "text_only"]
const NON_COMMERCIAL_SETTING: String = "npcf/providers/allow_non_commercial"
## Where the NPCs of one location stand around its anchor (the first four; more wrap around).
const SLOT_OFFSETS: PackedVector2Array = [Vector2(-60, -40), Vector2(60, -40), Vector2(-60, 40), Vector2(60, 40)]

@export var profile: String = "light"
@export var world_seed: int = 7
@export var sim_speed: float = 1.0
@export var use_models: bool = true

## Room centers on the ship. Rooms are CwShip.ROOM_SIZE.
var room_positions: Dictionary[StringName, Vector2] = {
	&"cw.production": Vector2(200, 200),
	&"cw.lounge": Vector2(600, 200),
	&"cw.dormitory": Vector2(1000, 200),
}

var _npcf: NpcfRuntime = null
var _started: bool = false
var _player: CwPlayer = null
var _hud: CwHud = null
var _overlay: CanvasLayer = null
var _rooms: Dictionary[StringName, Rect2] = {}
var _room_of_player: StringName = &""
var _slots: Dictionary[StringName, int] = {}


func _ready() -> void:
	var allow_non_commercial: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg.begins_with("--seed="):
			world_seed = arg.trim_prefix("--seed=").to_int()
		elif arg == "--allow-non-commercial":
			allow_non_commercial = true
		elif arg == "--no-models":
			use_models = false
	_npcf = get_node(RUNTIME_PATH) as NpcfRuntime
	var manifest: NpcfPackManifest = ResourceLoader.load(MANIFEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	var scenario: NpcfScenarioDef = ResourceLoader.load(SCENARIO_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	if manifest == null or scenario == null:
		push_error("cakeworks demo: cannot load %s or %s" % [MANIFEST_PATH, SCENARIO_PATH])
		return
	_npcf.sim_error.connect(func(message: String) -> void: push_error(message))
	if _npcf.start(manifest, scenario, world_seed) != OK:
		return
	_started = true
	_npcf.set_speed(sim_speed)
	for id: StringName in room_positions:
		_rooms[id] = CwShip.room_rect(room_positions[id])
	CwShip.build_rooms(self, manifest.location_graph, room_positions)
	var scene: PackedScene = load(NPC_SCENE) as PackedScene
	for id: StringName in _npcf.get_world().npc_ids:
		_spawn_npc(scene, id)
	_spawn_player()
	_overlay = _npcf.get_node_or_null(^"NpcfDebugOverlay") as CanvasLayer
	if _overlay != null:
		_overlay.visible = false
	if use_models:
		if allow_non_commercial:
			ProjectSettings.set_setting(NON_COMMERCIAL_SETTING, true)
		_use_profile()
	_hud = CwHud.new()
	add_child(_hud)
	_hud.setup(_npcf)
	_player.mic().transcript_ready.connect(_hud.show_transcript)


func _exit_tree() -> void:
	if _started and _npcf != null:
		_npcf.stop()


func _process(_delta: float) -> void:
	if not _started or not _npcf.is_running() or _player == null:
		return
	var room: StringName = _room_at(_player.position)
	if room != &"" and room != _room_of_player:
		_room_of_player = room
		_npcf.report_player_location(room)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F3:
		return
	if _overlay != null:
		_overlay.visible = not _overlay.visible
		get_viewport().set_input_as_handled()


## The provider set of the chosen profile, in use. Unknown profiles and missing files are reported, not fatal.
func _use_profile() -> void:
	if not PROFILES.has(profile):
		push_error("cakeworks demo: unknown profile '%s' (use light, full or text_only)" % profile)
		return
	var providers_set: NpcfProviderSet = ResourceLoader.load(PROFILE_DIR + profile + ".tres", "",
			ResourceLoader.CACHE_MODE_IGNORE) as NpcfProviderSet
	if providers_set == null:
		push_error("cakeworks demo: cannot load profile %s" % profile)
		return
	_npcf.use_providers(providers_set)


## Places an NPC body beside its location's anchor (one slot per NPC), with its agent and voice player set to the NPC ID before it enters.
func _spawn_npc(scene: PackedScene, id: StringName) -> void:
	var body: CharacterBody2D = scene.instantiate() as CharacterBody2D
	if body == null:
		push_error("cakeworks demo: cw_npc.tscn root is not a CharacterBody2D")
		return
	var agent: NpcfAgent2D = CwShip.agent_of(body)
	if agent == null:
		push_error("cakeworks demo: cw_npc.tscn has no NpcfAgent2D")
		return
	agent.npc_id = id
	for child: Node in body.get_children():
		if child is NpcfVoicePlayer2D:
			var voice: NpcfVoicePlayer2D = child as NpcfVoicePlayer2D
			voice.npc_id = id
	body.name = str(id).replace(".", "_")
	var location: StringName = _npcf.location_of(id)
	var slot: int = _slots.get(location, 0)
	_slots[location] = slot + 1
	body.position = _npcf.anchor_position(location) + SLOT_OFFSETS[slot % SLOT_OFFSETS.size()]
	body.add_to_group(&"cw_npc")
	add_child(body)


## The player body, at the lounge anchor (the scenario's player start).
func _spawn_player() -> void:
	_player = CwPlayer.new()
	_player.name = "Player"
	_player.position = _npcf.anchor_position(PLAYER_START)
	add_child(_player)


## The room whose rectangle holds the point, or &"" (sorted order, so overlaps resolve the same way every run).
func _room_at(point: Vector2) -> StringName:
	for id: StringName in _rooms:
		if _rooms[id].has_point(point):
			return id
	return &""
