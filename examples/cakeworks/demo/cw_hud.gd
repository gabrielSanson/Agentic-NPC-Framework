class_name CwHud
extends CanvasLayer
## The demo HUD. Top-left: day, clock, speed and the current policy era. Top-right: one row per provider with its
## state. Bottom: subtitles, the player's transcript, a hint, the typed-input line, and the "nobody is listening" note.
## Keys: Enter types, + and - change the speed, Space pauses.

const SUBTITLE_SECONDS: float = 6.0
const NOBODY_SECONDS: float = 3.0
const ERA_START: String = "Golden Standard"
const COLOR_READY: Color = Color(0.45, 0.85, 0.5)
const COLOR_CHECKING: Color = Color(0.92, 0.82, 0.3)
const COLOR_DOWN: Color = Color(0.92, 0.38, 0.35)
const COLOR_IDLE: Color = Color(0.7, 0.7, 0.7)

var _npcf: NpcfRuntime = null
var _header: Label = null
var _providers_box: VBoxContainer = null
var _subtitle: Label = null
var _you: Label = null
var _nobody: Label = null
var _input: LineEdit = null
var _subtitle_left: float = 0.0
var _you_left: float = 0.0
var _nobody_left: float = 0.0


func _ready() -> void:
	layer = 10
	_header = Label.new()
	_header.position = Vector2(12, 8)
	add_child(_header)
	_providers_box = VBoxContainer.new()
	add_child(_providers_box)
	_providers_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	var bottom: VBoxContainer = VBoxContainer.new()
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_subtitle = Label.new()
	bottom.add_child(_subtitle)
	_you = Label.new()
	bottom.add_child(_you)
	_nobody = Label.new()
	bottom.add_child(_nobody)
	var hint: Label = Label.new()
	hint.text = "Hold V to talk · Enter to type · F3 overlay"
	bottom.add_child(hint)
	var keys: Label = Label.new()
	keys.text = "Space pauses · +/- change speed"
	bottom.add_child(keys)
	_input = LineEdit.new()
	_input.placeholder_text = "Type to an NPC and press Enter"
	_input.custom_minimum_size = Vector2(520, 0)
	_input.text_submitted.connect(_on_text_submitted)
	bottom.add_child(_input)


## Wires the HUD to the started runtime. Call after use_providers, so the provider rows are known.
func setup(rt: NpcfRuntime) -> void:
	_npcf = rt
	rt.npc_line.connect(_on_npc_line)
	rt.no_addressee.connect(_on_no_addressee)
	rt.provider_status_changed.connect(_on_provider_status)
	_refresh_providers()


## Sends the player's typed line to the runtime. Returns the turn's line ID, or -1 when nothing was sent.
func submit(text: String) -> int:
	var t: String = text.strip_edges()
	if t.is_empty() or _npcf == null:
		return -1
	_input.text = ""
	_input.release_focus()
	return _npcf.player_say(t)


## Shows the microphone's transcript as "You: ...".
func show_transcript(text: String) -> void:
	_you.text = "You: %s" % text
	_you_left = SUBTITLE_SECONDS


## The subtitle line currently shown, or "".
func subtitle_text() -> String:
	return _subtitle.text


## The "nobody is listening" note currently shown, or "".
func nobody_text() -> String:
	return _nobody.text


func _process(delta: float) -> void:
	_subtitle_left = _count_down(_subtitle_left, delta, _subtitle)
	_you_left = _count_down(_you_left, delta, _you)
	_nobody_left = _count_down(_nobody_left, delta, _nobody)
	if _npcf == null or not _npcf.is_running():
		return
	var world: NpcfWorld = _npcf.get_world()
	var minute: int = world.clock.minute_of_day()
	var paused: String = "  (paused)" if _npcf.paused else ""
	_header.text = "Day %d  %02d:%02d   speed x%s   era: %s%s" % [world.clock.day() + 1, minute / 60,
			minute % 60, str(_npcf.speed), _era_name(world), paused]


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or _npcf == null:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_input.grab_focus()
		KEY_EQUAL, KEY_KP_ADD:
			_set_speed(_npcf.speed * 2.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_set_speed(_npcf.speed * 0.5)
		KEY_SPACE:
			if _npcf.paused:
				_npcf.resume()
			else:
				_npcf.pause()
		_:
			return
	get_viewport().set_input_as_handled()


func _set_speed(wanted: float) -> void:
	var clamped: float = clampf(wanted, NpcfRuntime.MIN_SPEED, NpcfRuntime.MAX_SPEED)
	_npcf.set_speed(clamped)


func _on_text_submitted(text: String) -> void:
	submit(text)


func _on_npc_line(npc: StringName, text: String, _line_id: int, _source: StringName, _presentation: Dictionary) -> void:
	_subtitle.text = "%s: %s" % [_speaker(npc), text]
	_subtitle_left = SUBTITLE_SECONDS


func _on_no_addressee(reason: StringName) -> void:
	_nobody.text = "Nobody is listening (%s)" % str(reason)
	_nobody_left = NOBODY_SECONDS


func _on_provider_status(_id: StringName, _state: StringName, _reason: String) -> void:
	_refresh_providers()


## Rebuilds the provider rows from the gateway (none when models are off).
func _refresh_providers() -> void:
	for child: Node in _providers_box.get_children():
		_providers_box.remove_child(child)
		child.queue_free()
	var gw: NpcfProviderGateway = _npcf.providers() if _npcf != null else null
	if gw == null:
		_add_row("models off", COLOR_IDLE, "no providers in use")
		return
	for id: StringName in gw.ids():
		var cfg: NpcfProviderConfig = gw.config(id)
		var state: StringName = gw.state(id)
		var reason: String = gw.reason(id)
		var uses: PackedStringArray = PackedStringArray()
		for use: StringName in cfg.use_for:
			uses.append(str(use))
		var text: String = "%s  %s  %s" % [str(id), ", ".join(uses), str(state)]
		if state == &"refused" and cfg.license_use == NpcfProviderConfig.License.NON_COMMERCIAL:
			text = "%s  %s  voice off: non-commercial opt-in needed" % [str(id), ", ".join(uses)]
		_add_row(text, _state_color(state), reason)


func _add_row(text: String, color: Color, tip: String) -> void:
	var row: Label = Label.new()
	row.text = text
	row.add_theme_color_override(&"font_color", color)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_providers_box.add_child(row)


func _state_color(state: StringName) -> Color:
	match state:
		&"ready":
			return COLOR_READY
		&"checking":
			return COLOR_CHECKING
		&"down", &"refused":
			return COLOR_DOWN
	return COLOR_IDLE


func _era_name(world: NpcfWorld) -> String:
	if world.directives == null:
		return ERA_START
	var best: NpcfDirective = null
	for d: NpcfDirective in world.directives.active():
		if best == null or d.priority > best.priority:
			best = d
	if best == null:
		return ERA_START
	match best.origin:
		&"cw.era_optimization":
			return "Quiet Optimization"
		&"cw.era_asset_protection":
			return "Asset Protection"
	return str(best.origin)


func _speaker(npc: StringName) -> String:
	if _npcf == null:
		return str(npc)
	var chars: Dictionary[StringName, NpcfCharacterDef] = _npcf.get_world().pack.characters
	var ch: NpcfCharacterDef = chars.get(npc, null)
	if ch == null or ch.display_name == "":
		return str(npc)
	return ch.display_name


## Lowers a timer by delta and clears the label when it runs out. Returns the new timer.
func _count_down(left: float, delta: float, label: Label) -> float:
	if left <= 0.0:
		return 0.0
	var next: float = left - delta
	if next <= 0.0:
		label.text = ""
		return 0.0
	return next
