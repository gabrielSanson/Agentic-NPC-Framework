class_name NpcfRuntime
extends Node
## The game-facing driver, registered as the autoload Npcf. Paces the world by frame time (speed, pause,
## a per-frame tick cap), turns game reports into inputs and re-emits each tick's results as signals. It
## holds no simulation state beyond the pacing counters, and it does nothing until start().

signal tick_advanced(tick: int)
signal action_started(npc: StringName, action: StringName, call_id: int)
signal action_finished(npc: StringName, action: StringName, call_id: int, outcome: StringName)
signal npc_line(npc: StringName, text: String, line_id: int, source: StringName)
signal no_addressee(reason: StringName)
signal sim_error(message: String)

const MIN_SPEED: float = 0.25
const MAX_SPEED: float = 16.0

## When false, _process does nothing; tests drive frames with advance_frame().
var auto_process: bool = true
## Read-only from outside; change it with set_speed.
var speed: float = 1.0
var paused: bool = false
## Frames that hit max_ticks_per_frame with time still owed.
var capped_frames: int = 0
var frames: int = 0
var agents: NpcfAgentRegistry2D = NpcfAgentRegistry2D.new()

var _world: NpcfWorld = null
var _acc: float = 0.0
var _movement: NpcfMovementAdapter = null
var _perception: NpcfPerceptionAdapter = null
var _presentation: NpcfPresentationAdapter = null


## Loads and validates the pack, checks the scenario and builds a running world. Returns OK, or the reason.
## `pack_dir` is the folder hook scripts must live in when the manifest has no file (a generated pack);
## empty means the manifest's own folder.
func start(manifest: NpcfPackManifest, scenario: NpcfScenarioDef, world_seed: int, pack_dir: String = "") -> Error:
	if _world != null:
		return ERR_ALREADY_IN_USE
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	var loaded: NpcfLoadResult = loader.load_pack(manifest, NpcfVersion.FRAMEWORK, pack_dir)
	if not loaded.ok:
		sim_error.emit(loaded.format_errors())
		return ERR_INVALID_DATA
	if scenario == null:
		sim_error.emit("no scenario given")
		return ERR_INVALID_DATA
	var scenario_errors: Array[NpcfConfigError] = loader.check_scenario(loaded.pack, scenario)
	if not scenario_errors.is_empty():
		var lines: PackedStringArray = []
		for e: NpcfConfigError in scenario_errors:
			lines.append(e.format())
		sim_error.emit("\n".join(lines))
		return ERR_INVALID_DATA
	if loaded.pack.sim.real_seconds_per_tick <= 0.0:
		sim_error.emit("sim.real_seconds_per_tick must be above 0")
		return ERR_INVALID_DATA

	agents.player_entity = loaded.pack.sim.player_entity
	agents.scene_source = self
	var defaults: NpcfAdapterSet = NpcfAdapters2D.make_set(agents)
	var adapters: NpcfAdapterSet = NpcfAdapterSet.make(
		_movement if _movement != null else defaults.movement,
		_perception if _perception != null else defaults.perception,
		_presentation if _presentation != null else defaults.presentation)
	_world = NpcfWorldBuilder.build(loaded.pack, scenario, world_seed, adapters)
	_world.headless = false
	_acc = 0.0
	capped_frames = 0
	frames = 0
	paused = false
	for npc: StringName in agents.ids():
		_world.queue_input(NpcfInput.embodiment(npc, true))
	return OK


## Releases the world. Safe to call when nothing runs.
func stop() -> void:
	if _world == null:
		return
	_world.dispose()
	_world = null


func is_running() -> bool:
	return _world != null


func get_world() -> NpcfWorld:
	return _world


func pause() -> void:
	paused = true


func resume() -> void:
	paused = false


## Sets the simulation speed. Outside MIN_SPEED..MAX_SPEED the speed is left unchanged.
func set_speed(m: float) -> Error:
	if m < MIN_SPEED or m > MAX_SPEED:
		return ERR_PARAMETER_RANGE_ERROR
	speed = m
	return OK


## Adds the frame's game time to the accumulator and runs whole ticks from it. Returns the ticks stepped.
## Time never drops: what the cap leaves over carries into the next frame.
func advance_frame(delta: float) -> int:
	if _world == null or paused:
		return 0
	frames += 1
	_acc += delta * speed
	var interval: float = _world.sim.real_seconds_per_tick
	var steps: int = 0
	while _world != null and _acc >= interval and steps < _world.sim.max_ticks_per_frame:
		_acc -= interval
		_step()
		steps += 1
	if _world != null and _acc >= interval:
		capped_frames += 1
	return steps


func set_movement_adapter(a: NpcfMovementAdapter) -> Error:
	if _world != null:
		return ERR_ALREADY_IN_USE
	_movement = a
	return OK


func set_perception_adapter(a: NpcfPerceptionAdapter) -> Error:
	if _world != null:
		return ERR_ALREADY_IN_USE
	_perception = a
	return OK


func set_presentation_adapter(a: NpcfPresentationAdapter) -> Error:
	if _world != null:
		return ERR_ALREADY_IN_USE
	_presentation = a
	return OK


## Associates an NPC with its agent node. While running, the NPC is embodied from the next tick.
func register_npc_node(npc: StringName, agent: NpcfAgent2D) -> Error:
	if agent == null:
		return ERR_INVALID_PARAMETER
	if _world != null and _world.npc(npc) == null:
		return ERR_DOES_NOT_EXIST
	agents.add(npc, agent)
	if _world != null:
		_world.queue_input(NpcfInput.embodiment(npc, true))
	return OK


## Removes an NPC's agent. While running, the NPC is disembodied from the next tick.
func unregister_npc_node(npc: StringName) -> void:
	agents.remove(npc)
	if _world != null and _world.npc(npc) != null:
		_world.queue_input(NpcfInput.embodiment(npc, false))


## Queues a game event for the next tick. A kind or payload the pack rejects gives ERR_INVALID_PARAMETER
## and one sim_error.
func report_event(kind: StringName, actors: Array[StringName], targets: Array[StringName], location: StringName,
		payload: Dictionary[StringName, Variant]) -> Error:
	if _world == null:
		return ERR_UNCONFIGURED
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = kind
	e.actors.assign(actors)
	e.targets.assign(targets)
	e.location = location
	e.payload = payload.duplicate()
	var reason: String = _world.events.validate(e)
	if reason != "":
		sim_error.emit(reason)
		return ERR_INVALID_PARAMETER
	_world.queue_input(NpcfInput.event_input(e))
	return OK


## Queues the player's arrival at a location. Needs a player entity in the pack and a known location.
func report_player_location(location: StringName) -> Error:
	if _world == null or _world.sim.player_entity == &"":
		return ERR_UNCONFIGURED
	if not _world.pack.location_index.has_location(location):
		return ERR_DOES_NOT_EXIST
	_world.queue_input(NpcfInput.arrived(_world.sim.player_entity, location))
	return OK


func report_arrived(npc: StringName, location: StringName) -> void:
	if _world != null:
		_world.queue_input(NpcfInput.arrived(npc, location))


func report_move_failed(npc: StringName, call_id: int, reason: StringName) -> void:
	if _world != null:
		_world.queue_input(NpcfInput.move_failed(npc, call_id, reason))


## The game reports that an action it presents has finished (or failed). Ignored unless call_id is running.
func finish_action(npc: StringName, call_id: int, success: bool = true, reason: StringName = &"") -> void:
	if _world != null:
		_world.queue_input(NpcfInput.action_finished(npc, call_id, success, reason))


## Where an entity is, or &"" when the simulation is not running.
func location_of(entity: StringName) -> StringName:
	return _world.location_of(entity) if _world != null else &""


func anchor_position(location: StringName) -> Vector2:
	return agents.anchor_position(location)


## A debugging snapshot of one NPC, or {} when it is not an NPC of the running world.
func trace(npc: StringName) -> Dictionary:
	var n: NpcfNpcState = _world.npc(npc) if _world != null else null
	if n == null:
		return {}
	var records: Array = []
	for r: NpcfDecisionRecord in n.decision_records:
		records.append(r.to_dict())
	var running: String = String(n.running.call.action) if n.running != null else ""
	return {"npc": String(npc), "goal": String(n.current_goal), "running": running, "decisions": records}


## Dialogue arrives in task 19.
func player_say(_text: String, _npc: StringName = &"") -> void:
	push_warning("player_say arrives in task 19")


## Saving arrives in task 21.
func save_game(_slot: String) -> Error:
	return ERR_UNAVAILABLE


## Loading arrives in task 21.
func load_game(_slot: String, _use_backup: bool = false) -> Error:
	return ERR_UNAVAILABLE


func _process(delta: float) -> void:
	if auto_process:
		advance_frame(delta)


func _step() -> void:
	var r: NpcfTickReport = _world.step()
	tick_advanced.emit(r.tick)
	for o: NpcfActionOutcome in r.started:
		action_started.emit(o.npc, o.action, o.call_id)
	for o: NpcfActionOutcome in r.finished:
		action_finished.emit(o.npc, o.action, o.call_id, o.outcome)
	for f: NpcfInvariantFailure in r.invariant_failures:
		sim_error.emit(f.format())
