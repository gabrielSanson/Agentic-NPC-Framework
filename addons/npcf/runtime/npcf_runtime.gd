class_name NpcfRuntime
extends Node
## The game-facing driver, registered as the autoload Npcf. Paces the world by frame time (speed, pause,
## a per-frame tick cap), turns game reports into inputs and re-emits each tick's results as signals. It
## holds no simulation state beyond the pacing counters, and it does nothing until start().

signal tick_advanced(tick: int)
signal action_started(npc: StringName, action: StringName, call_id: int)
signal action_finished(npc: StringName, action: StringName, call_id: int, outcome: StringName)
## One line per dialogue turn. `source` is &"authored" or the generator's name; `presentation` maps each presentation
## question ID to its answer (the game may use it, it never changes state).
signal npc_line(npc: StringName, text: String, line_id: int, source: StringName, presentation: Dictionary)
## A dialogue turn that could not start: nobody to address (reason none_in_range, ambiguous, unknown_npc ...),
## busy, not_running, no_dialogue or no_player.
signal no_addressee(reason: StringName)
## A model provider changed state (relayed from the provider gateway; the reason never holds a key).
signal provider_status_changed(id: StringName, state: StringName, reason: String)
signal sim_error(message: String)

const MIN_SPEED: float = 0.25
const MAX_SPEED: float = 16.0
## Sample rates the voice calls use: transcribe takes 16 kHz mono PCM, speak returns 24 kHz mono PCM.
const TRANSCRIBE_SAMPLE_RATE: int = 16000
const SPEECH_SAMPLE_RATE: int = 24000
## The save slot autosave writes to.
const AUTOSAVE_SLOT: String = "autosave"

## When false, _process does nothing; tests drive frames with advance_frame().
var auto_process: bool = true
## Read-only from outside; change it with set_speed.
var speed: float = 1.0
var paused: bool = false
## Frames that hit max_ticks_per_frame with time still owed.
var capped_frames: int = 0
var frames: int = 0
var agents: NpcfAgentRegistry2D = NpcfAgentRegistry2D.new()
## Save files (save_game and load_game). Tests point `saves.dir` at a test folder.
var saves: NpcfSaveService = NpcfSaveService.new()
## Real seconds between autosaves into the "autosave" slot; 0 disables. Read from npcf/save/autosave_seconds at start.
var autosave_seconds: float = 300.0

var _world: NpcfWorld = null
var _acc: float = 0.0
var _pack: NpcfLoadedPack = null
var _scenario: NpcfScenarioDef = null
var _adapters: NpcfAdapterSet = null
var _autosave_elapsed: float = 0.0
var _movement: NpcfMovementAdapter = null
var _perception: NpcfPerceptionAdapter = null
var _presentation: NpcfPresentationAdapter = null
var _classifier: NpcfIntentClassifier = null
var _chooser: NpcfPresentationChooser = null
var _generator: NpcfLineGenerator = null
var _gateway: NpcfProviderGateway = null


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
	_pack = loaded.pack
	_scenario = scenario
	_adapters = adapters
	_install_world(NpcfWorldBuilder.build(loaded.pack, scenario, world_seed, adapters))
	capped_frames = 0
	frames = 0
	paused = false
	var seconds: float = ProjectSettings.get_setting("npcf/save/autosave_seconds", 300.0)
	autosave_seconds = seconds
	_autosave_elapsed = 0.0
	return OK


## Releases the world. Safe to call when nothing runs. Also forgets the pack, so load_game needs start() again.
func stop() -> void:
	if _world != null:
		_world.dispose()
	_world = null
	_pack = null
	_scenario = null
	_adapters = null


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
	_tick_autosave(delta)
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
	if _world == null:
		return {}
	var out: Dictionary = NpcfTraceService.trace(_world, npc)
	if not out.is_empty() and _gateway != null:
		var calls: Array = []
		for i: int in range(maxi(0, _gateway.calls.size() - 10), _gateway.calls.size()):
			calls.append(_gateway.calls[i].to_dict())
		out["providers"] = calls
	return out


## The player says `text`, to `npc` or to whoever is addressed. Returns the turn's line ID, or -1 after emitting
## no_addressee. Works while paused.
func player_say(text: String, npc: StringName = &"") -> int:
	if _world == null:
		no_addressee.emit(&"not_running")
		return -1
	return _world.dialogue.begin_turn(_world, text, npc)


## Replaces the intent classifier for every later turn. Null restores the keyword classifier.
func set_intent_classifier(c: NpcfIntentClassifier) -> void:
	_classifier = c
	_apply_dialogue_plugins()


## Replaces the presentation chooser. Null restores the rule-based chooser.
func set_presentation_chooser(c: NpcfPresentationChooser) -> void:
	_chooser = c
	_apply_dialogue_plugins()


## Replaces the line generator. Null restores the authored lines only.
func set_line_generator(g: NpcfLineGenerator) -> void:
	_generator = g
	_apply_dialogue_plugins()


## Replaces every model provider with the ones in `providers_set`. The first provider with &"lines" in use_for
## becomes the line generator; the first with &"intents" the intent classifier and the first with &"presentation" the
## presentation chooser. Wiring does not wait for health: the bridges fall back while a provider is down.
func use_providers(providers_set: NpcfProviderSet) -> Error:
	if providers_set == null:
		return ERR_INVALID_PARAMETER
	var was_provider_generator: bool = _generator_is_provider()
	if _gateway != null:
		_gateway.close()
		_gateway.free()
		_gateway = null
	_gateway = NpcfProviderGateway.new()
	_gateway.name = "Providers"
	add_child(_gateway)
	_gateway.status_changed.connect(_relay_provider_status)
	for cfg: NpcfProviderConfig in providers_set.providers:
		_gateway.add_provider(cfg)
	var wired: bool = false
	var classifier_wired: bool = false
	var chooser_wired: bool = false
	for id: StringName in _gateway.ids():
		var uses: Array[StringName] = _gateway.config(id).use_for
		if not wired and uses.has(&"lines"):
			set_line_generator(NpcfLlmLineGenerator.new(NpcfProviderLlmTransport.new(_gateway, id)))
			wired = true
		if not classifier_wired and uses.has(&"intents"):
			set_intent_classifier(NpcfProviderIntentClassifier.new(_gateway, id))
			classifier_wired = true
		if not chooser_wired and uses.has(&"presentation"):
			set_presentation_chooser(NpcfProviderPresentationChooser.new(_gateway, id))
			chooser_wired = true
	if not wired and was_provider_generator:
		set_line_generator(null)
	if not classifier_wired and _classifier is NpcfProviderIntentClassifier:
		set_intent_classifier(null)
	if not chooser_wired and _chooser is NpcfProviderPresentationChooser:
		set_presentation_chooser(null)
	return OK


## The provider gateway (null until providers are set).
func providers() -> NpcfProviderGateway:
	return _gateway


## Transcribes 16 kHz mono 16-bit PCM through the first ready voice_in provider. on_done gets (text, status): status
## is &"off" when there is no such provider, &"http" when the reply is ok but empty, else the request's status.
func transcribe(pcm16_mono_16k: PackedByteArray, on_done: Callable) -> void:
	var id: StringName = _gateway.first_ready_for(&"voice_in") if _gateway != null else &""
	if id == &"":
		on_done.call("", &"off")
		return
	var adapter: NpcfOpenAiTranscribeAdapter = _gateway.adapter(id) as NpcfOpenAiTranscribeAdapter
	if adapter == null:
		on_done.call("", &"off")
		return
	var spec: NpcfHttpSpec = adapter.build(_gateway.config(id), pcm16_mono_16k, NpcfMultipart.new_boundary())
	_gateway.send(id, spec, func(r: NpcfHttpResult) -> void:
		var text: String = adapter.parse(r)
		var status: StringName = r.status
		if status == &"ok" and text == "":
			status = &"http"
		on_done.call(text, status))


## Speaks text through the first ready voice_out provider. on_chunk gets whole 24 kHz mono s16le samples as they
## arrive; on_done gets the status (&"off" when there is no such provider). A truncated reply ends as &"http": the
## chunks already delivered stand, and nothing more is claimed.
func speak(text: String, instruction: String, voice_id: String, on_chunk: Callable, on_done: Callable) -> void:
	var id: StringName = _gateway.first_ready_for(&"voice_out") if _gateway != null else &""
	if id == &"":
		on_done.call(&"off")
		return
	var adapter: NpcfBreezeSpeechAdapter = _gateway.adapter(id) as NpcfBreezeSpeechAdapter
	if adapter == null:
		on_done.call(&"off")
		return
	var spec: NpcfHttpSpec = adapter.build(_gateway.config(id), text, instruction, voice_id, NpcfMultipart.new_boundary())
	var stream: NpcfBreezeSpeechAdapter.Stream = NpcfBreezeSpeechAdapter.Stream.new()
	_gateway.send(id, spec, func(r: NpcfHttpResult) -> void: on_done.call(r.status), func(piece: PackedByteArray) -> void:
		var out: PackedByteArray = stream.feed(piece)
		if not out.is_empty():
			on_chunk.call(out))


## Dialogue turn records of the running world (the last NpcfDialogueService.RECORD_CAP turns), or none.
func dialogue_records() -> Array[NpcfDialogueTurnRecord]:
	var out: Array[NpcfDialogueTurnRecord] = []
	if _world != null:
		out.append_array(_world.dialogue.records)
	return out


## Writes the running world to a save slot. Refused (nothing written) when an invariant fails.
func save_game(slot: String) -> Error:
	if _world == null:
		return ERR_UNCONFIGURED
	var failures: Array[NpcfInvariantFailure] = _world.invariants.check(_world)
	if not failures.is_empty():
		var lines: PackedStringArray = []
		for f: NpcfInvariantFailure in failures:
			lines.append(f.format())
		sim_error.emit("save refused, invariants failed:\n" + "\n".join(lines))
		return ERR_INVALID_DATA
	var data: Dictionary = NpcfSaveCodec.encode(_world)
	if data.is_empty():
		sim_error.emit("save refused: " + NpcfSaveCodec.last_error())
		return ERR_INVALID_DATA
	var written: Error = saves.write(slot, NpcfSaveCodec.to_text(data))
	if written != OK:
		sim_error.emit("save to slot %s failed: %s" % [slot, error_string(written)])
	return written


## Replaces the running world with a saved one (same pack and scenario). Files and the running world are
## untouched when the save is refused.
func load_game(slot: String, use_backup: bool = false) -> Error:
	if _pack == null:
		return ERR_UNCONFIGURED
	var read_result: Array = saves.read(slot, use_backup)
	var read_error: Error = read_result[0]
	if read_error != OK:
		sim_error.emit(str(read_result[1]))
		return read_error
	var data: Dictionary = NpcfSaveCodec.parse(str(read_result[1]))
	var header: String = NpcfSaveCodec.check_compatible(data, _pack, _scenario)
	if header != "":
		sim_error.emit(header)
		return ERR_FILE_CORRUPT
	var w: NpcfWorld = NpcfWorldBuilder.build(_pack, _scenario, NpcfSaveCodec.seed_of(data), _adapters)
	var restore_error: String = NpcfSaveCodec.restore(w, data)
	if restore_error != "":
		w.dispose()
		sim_error.emit("load failed: " + restore_error)
		return ERR_FILE_CORRUPT
	if _world != null:
		_world.dispose()
	_install_world(w)
	tick_advanced.emit(w.clock.tick)
	return OK


func _process(delta: float) -> void:
	if auto_process:
		advance_frame(delta)


func _apply_dialogue_plugins() -> void:
	if _world == null:
		return
	_world.dialogue.classifier = _classifier if _classifier != null else NpcfKeywordIntentClassifier.new()
	_world.dialogue.chooser = _chooser if _chooser != null else NpcfPresentationChooser.new()
	_world.dialogue.generator = _generator if _generator != null else NpcfLineGenerator.new()


func _relay_line(npc: StringName, text: String, line_id: int, source: StringName, presentation: Dictionary) -> void:
	npc_line.emit(npc, text, line_id, source, presentation)


func _relay_no_addressee(reason: StringName) -> void:
	no_addressee.emit(reason)


func _relay_provider_status(id: StringName, state: StringName, reason: String) -> void:
	provider_status_changed.emit(id, state, reason)


## Loads the provider set named by the project setting npcf/providers/set, when no providers are set yet.
func _load_providers_from_settings() -> void:
	if _gateway != null:
		return
	var path: String = str(ProjectSettings.get_setting("npcf/providers/set", ""))
	if path == "":
		return
	var loaded: Resource = ResourceLoader.load(path)
	var providers_set: NpcfProviderSet = loaded as NpcfProviderSet
	if providers_set == null:
		push_error("npcf: could not load the provider set %s" % path)
		return
	use_providers(providers_set)


func _generator_is_provider() -> bool:
	var lg: NpcfLlmLineGenerator = _generator as NpcfLlmLineGenerator
	return lg != null and lg.transport is NpcfProviderLlmTransport


func _step() -> void:
	var r: NpcfTickReport = _world.step()
	tick_advanced.emit(r.tick)
	for o: NpcfActionOutcome in r.started:
		action_started.emit(o.npc, o.action, o.call_id)
	for o: NpcfActionOutcome in r.finished:
		action_finished.emit(o.npc, o.action, o.call_id, o.outcome)
	for f: NpcfInvariantFailure in r.invariant_failures:
		sim_error.emit(f.format())


## Makes `w` the running world: signal connections, dialogue plugins, providers (loaded once), and the
## embodiment inputs for registered agents. Used by start() and load_game().
func _install_world(w: NpcfWorld) -> void:
	_world = w
	_world.headless = false
	_world.dialogue.line.connect(_relay_line)
	_world.dialogue.no_addressee.connect(_relay_no_addressee)
	_apply_dialogue_plugins()
	_load_providers_from_settings()
	_acc = 0.0
	for npc: StringName in agents.ids():
		_world.queue_input(NpcfInput.embodiment(npc, true))


## Adds the frame's real time to the autosave clock and saves into the "autosave" slot when it is due.
func _tick_autosave(delta: float) -> void:
	if autosave_seconds <= 0.0:
		return
	_autosave_elapsed += delta
	if _autosave_elapsed < autosave_seconds:
		return
	_autosave_elapsed = 0.0
	save_game(AUTOSAVE_SLOT)
