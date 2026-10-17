class_name NpcfVoicePlayer2D
extends AudioStreamPlayer2D
## Speaks one NPC's lines from where it stands. On npc_line it emits subtitle first, then asks Npcf.speak and
## plays the 24 kHz PCM as it streams in. A newer line interrupts the current one. Out of earshot of the player
## the audio is dropped (the subtitle still went out).

signal subtitle(npc: StringName, text: String, line_id: int, presentation: Dictionary)
signal speech_started(line_id: int)
## Once per line: status from Npcf.speak (&"ok", &"off", &"http" ...) or &"interrupted" / &"out_of_earshot".
signal speech_finished(line_id: int, status: StringName)

## The NPC this player speaks for. Empty = the npc_id of an NpcfAgent2D sibling (same parent), read at _ready.
@export var npc_id: StringName = &""
## Max distance in pixels to the npcf_player body for audio. 0 or less = always audible.
@export var earshot_px: float = 600.0
## Generator buffer in seconds.
@export var buffer_seconds: float = 0.5
@export var runtime_path: NodePath = ^"/root/Npcf"

var _line_id: int = -1
var _pending: PackedVector2Array = []
var _done_status: StringName = &""
var _finished_sent: bool = true
var _started: bool = false
var _dropped: bool = false


func _ready() -> void:
	if npc_id == &"" and get_parent() != null:
		for c: Node in get_parent().get_children():
			if c is NpcfAgent2D:
				var agent: NpcfAgent2D = c
				npc_id = agent.npc_id
				break
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = float(NpcfRuntime.SPEECH_SAMPLE_RATE)
	gen.buffer_length = buffer_seconds
	stream = gen
	var rt: NpcfRuntime = runtime()
	if rt != null:
		rt.npc_line.connect(_on_npc_line)


func _on_npc_line(npc: StringName, text: String, line_id: int, _source: StringName, presentation: Dictionary) -> void:
	if npc != npc_id:
		return
	if not _finished_sent:
		_finish(&"interrupted")
	_pending = []
	_line_id = line_id
	_done_status = &""
	_finished_sent = false
	_started = false
	_dropped = false
	stop()
	subtitle.emit(npc, text, line_id, presentation)
	var rt: NpcfRuntime = runtime()
	var instr: String = rt.speech_instruction(npc, presentation) if rt != null else ""
	var vid: String = rt.speech_voice_id(npc) if rt != null else ""
	var me: WeakRef = weakref(self)
	request_speech(text, instr, vid,
		func(pcm: PackedByteArray) -> void:
			var obj: Object = me.get_ref()
			if obj is NpcfVoicePlayer2D:
				var n: NpcfVoicePlayer2D = obj
				n.push_pcm(line_id, pcm),
		func(status: StringName) -> void:
			var obj: Object = me.get_ref()
			if obj is NpcfVoicePlayer2D:
				var n: NpcfVoicePlayer2D = obj
				n.end_pcm(line_id, status))


## Overridable seam: asks Npcf.speak (or answers &"off" when there is no runtime).
func request_speech(text: String, instruction: String, voice_id: String, on_chunk: Callable, on_done: Callable) -> void:
	var rt: NpcfRuntime = runtime()
	if rt == null:
		on_done.call(&"off")
		return
	rt.speak(text, instruction, voice_id, on_chunk, on_done)


func push_pcm(line_id: int, pcm: PackedByteArray) -> void:
	if line_id != _line_id or _finished_sent or _dropped:
		return
	if not in_earshot():
		_dropped = true
		_pending = []
		stop()
		return
	_pending.append_array(NpcfPcm.s16le_to_frames(pcm))
	if not _started and is_inside_tree():
		play()
		_started = true
		speech_started.emit(line_id)
	_pump()


func end_pcm(line_id: int, status: StringName) -> void:
	if line_id != _line_id or _finished_sent:
		return
	_done_status = status
	if _dropped:
		_finish(&"out_of_earshot")
	elif _pending.is_empty():
		_finish(status)


func _process(_delta: float) -> void:
	if _finished_sent:
		return
	if _started and not in_earshot():
		_dropped = true
		_pending = []
		stop()
		if _done_status != &"":
			_finish(&"out_of_earshot")
		return
	_pump()
	if _done_status != &"" and _pending.is_empty():
		_finish(_done_status)


func _pump() -> void:
	if not playing:
		return
	var pb: AudioStreamGeneratorPlayback = get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n: int = mini(pb.get_frames_available(), _pending.size())
	if n > 0:
		pb.push_buffer(_pending.slice(0, n))
		_pending = _pending.slice(n)


func _finish(status: StringName) -> void:
	if not _finished_sent:
		_finished_sent = true
		speech_finished.emit(_line_id, status)


## True when there is no player in group npcf_player, or it is within earshot_px (0 or less = always).
func in_earshot() -> bool:
	if earshot_px <= 0.0:
		return true
	if not is_inside_tree():
		return true
	for n: Node in get_tree().get_nodes_in_group(&"npcf_player"):
		if n is Node2D:
			var p: Node2D = n
			return global_position.distance_to(p.global_position) <= earshot_px
	return true


func runtime() -> NpcfRuntime:
	if not is_inside_tree():
		return null
	var node: Node = get_node_or_null(runtime_path)
	if node is NpcfRuntime:
		var rt: NpcfRuntime = node
		return rt
	return null


func pending_frames() -> int:
	return _pending.size()


func current_line() -> int:
	return _line_id
