class_name NpcfMicCapture
extends Node
## Push-to-talk microphone input. While the action is held it records from a muted capture bus; on release it
## sends 16 kHz mono PCM to Npcf.transcribe and hands the text to Npcf.player_say. transcript_ready fires before
## the NPC can answer. Needs the project setting audio/driver/enable_input (and OS microphone permission).

signal recording_started()
signal recording_stopped(seconds: float)
## The recognised text, emitted before it is passed to player_say.
signal transcript_ready(text: String)
## No text this time: &"too_short", &"empty", or the transcribe status (&"off", &"http", &"timeout" ...).
signal transcribe_failed(status: StringName)

## Input action that records while held. Created at _ready (bound to default_key) when the project lacks it.
@export var push_to_talk_action: StringName = &"npcf_push_to_talk"
@export var default_key: Key = KEY_V
## Capture bus (created muted when missing, so the player does not hear themselves).
@export var bus_name: StringName = &"NpcfMic"
@export var max_seconds: float = 15.0
@export var min_seconds: float = 0.3
## Who the player talks to. Empty = let dialogue pick the addressee.
@export var addressee: StringName = &""
@export var runtime_path: NodePath = ^"/root/Npcf"
## Input sample rate. 0 = AudioServer.get_mix_rate(). Tests set it.
var source_rate: int = 0

var _capture: AudioEffectCapture = null
var _mic: AudioStreamPlayer = null
var _frames: PackedVector2Array = []
var _recording: bool = false
var _busy: bool = false
var _warned: bool = false


func _ready() -> void:
	if not InputMap.has_action(push_to_talk_action):
		InputMap.add_action(push_to_talk_action)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = default_key
		InputMap.action_add_event(push_to_talk_action, key)
	var i: int = AudioServer.get_bus_index(bus_name)
	if i == -1:
		i = AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_mute(i, true)
	_capture = _find_capture(i)
	if _capture == null:
		var fx: AudioEffectCapture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(i, fx)
		_capture = fx
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = bus_name
	add_child(_mic)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(push_to_talk_action, false):
		start()
	elif event.is_action_released(push_to_talk_action):
		stop()


func _process(_delta: float) -> void:
	if _recording:
		_drain()
		_check_max()


## Test seam: appends frames while recording (ignored otherwise).
func feed(frames: PackedVector2Array) -> void:
	if not _recording:
		return
	_frames.append_array(frames)
	_check_max()


func start() -> void:
	if _recording or _busy:
		return
	var enabled: bool = ProjectSettings.get_setting("audio/driver/enable_input", false)
	if not enabled and not _warned:
		push_warning("NpcfMicCapture: set audio/driver/enable_input in the project settings to record.")
		_warned = true
	_frames.clear()
	if _capture != null:
		_capture.clear_buffer()
	if _mic.is_inside_tree():
		_mic.play()
	_recording = true
	recording_started.emit()


func stop() -> void:
	if not _recording:
		return
	_drain()
	_mic.stop()
	_recording = false
	var secs: float = NpcfPcm.seconds(_frames.size(), _rate())
	recording_stopped.emit(secs)
	if secs < min_seconds:
		_frames.clear()
		transcribe_failed.emit(&"too_short")
		return
	var mono: PackedFloat32Array = NpcfPcm.to_mono(_frames)
	var pcm: PackedByteArray = NpcfPcm.to_s16le(NpcfPcm.resample(mono, _rate(), NpcfRuntime.TRANSCRIBE_SAMPLE_RATE))
	_frames.clear()
	_busy = true
	var me: WeakRef = weakref(self)
	send_for_transcription(pcm, func(text: String, status: StringName) -> void:
		var obj: Object = me.get_ref()
		if obj is NpcfMicCapture:
			var node: NpcfMicCapture = obj
			node._on_transcribed(text, status))


## Overridable seam: sends the PCM to Npcf.transcribe (or answers &"off" when there is no runtime).
func send_for_transcription(pcm: PackedByteArray, on_done: Callable) -> void:
	var rt: NpcfRuntime = runtime()
	if rt == null:
		on_done.call("", &"off")
		return
	rt.transcribe(pcm, on_done)


## Overridable seam: hands the recognised text to Npcf.player_say.
func deliver_transcript(text: String) -> void:
	var rt: NpcfRuntime = runtime()
	if rt != null:
		rt.player_say(text, addressee)


func is_recording() -> bool:
	return _recording


func is_busy() -> bool:
	return _busy


func runtime() -> NpcfRuntime:
	if not is_inside_tree():
		return null
	var node: Node = get_node_or_null(runtime_path)
	if node is NpcfRuntime:
		var rt: NpcfRuntime = node
		return rt
	return null


func _on_transcribed(text: String, status: StringName) -> void:
	_busy = false
	if status != &"ok":
		transcribe_failed.emit(status)
		return
	var t: String = text.strip_edges()
	if t.is_empty():
		transcribe_failed.emit(&"empty")
		return
	transcript_ready.emit(t)
	deliver_transcript(t)


func _drain() -> void:
	_frames.append_array(read_captured_frames())


## Overridable seam: the frames the capture bus holds since the last read (empty without a capture effect).
func read_captured_frames() -> PackedVector2Array:
	if _capture == null:
		return PackedVector2Array()
	return _capture.get_buffer(_capture.get_frames_available())


func _check_max() -> void:
	if _recording and _frames.size() >= int(max_seconds * float(_rate())):
		stop()


func _rate() -> int:
	if source_rate > 0:
		return source_rate
	return int(AudioServer.get_mix_rate())


func _find_capture(bus: int) -> AudioEffectCapture:
	for k: int in AudioServer.get_bus_effect_count(bus):
		var fx: AudioEffect = AudioServer.get_bus_effect(bus, k)
		if fx is AudioEffectCapture:
			var cap: AudioEffectCapture = fx
			return cap
	return null
