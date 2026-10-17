class_name NpcfDebugOverlay
extends CanvasLayer
## Debug panel for one NPC at a time. F9 toggles it, F10 cycles NPCs, a left click selects the nearest registered
## NPC within 48 px (clicks pass through to the game). Shows Npcf.trace(npc) as a Tree with the top-level sections
## collapsed. Refreshes every 0.5 s while visible. Built in code, no scene file.

const PANEL_WIDTH: float = 420.0
const TREE_HEIGHT: float = 480.0
const CLICK_RADIUS: float = 48.0
const REFRESH_SECONDS: float = 0.5

## The runtime whose NPCs the panel shows (set by the runtime when it adds the overlay).
var runtime: NpcfRuntime = null
## The NPC shown; &"" when none is selected.
var selected: StringName = &""

var _title: Label = null
var _tree: Tree = null
var _elapsed: float = 0.0
## Top-level section names the user expanded, kept across refreshes.
var _open_sections: Dictionary[String, bool] = {}


## True when the overlay is added: in debug builds, or in release builds when the project setting allows it.
static func should_add(debug_build: bool, enabled_in_release: bool) -> bool:
	return debug_build or enabled_in_release


func _ready() -> void:
	layer = 100
	visible = false
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	_title = Label.new()
	column.add_child(_title)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 1
	_tree.custom_minimum_size = Vector2(PANEL_WIDTH, TREE_HEIGHT)
	column.add_child(_tree)
	_tree.item_collapsed.connect(_on_item_collapsed)
	refresh()


## Selects the next NPC of the running world in ID order, wrapping; &"" when there is none.
func select_next() -> void:
	var ids: Array[StringName] = _world_ids()
	if ids.is_empty():
		selected = &""
		return
	var index: int = ids.find(selected)
	selected = ids[(index + 1) % ids.size()]


## Fills the tree with the trace of the selected NPC. Works while hidden too.
func refresh() -> void:
	if _tree == null:
		return
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var data: Dictionary = {}
	if runtime != null and selected != &"":
		data = runtime.trace(selected)
	if data.is_empty():
		_title.text = "Npcf: no NPC selected"
		return
	_title.text = "Npcf trace: %s" % str(selected)
	var keys: Array = data.keys()
	keys.sort()
	for key: Variant in keys:
		var label: String = str(key)
		var value: Variant = data[key]
		var item: TreeItem = _tree.create_item(root)
		if value is Dictionary or value is Array:
			var was_open: bool = _open_sections.get(label, false)
			item.set_text(0, label)
			_fill_children(item, value)
			item.collapsed = not was_open
		else:
			item.set_text(0, "%s: %s" % [label, str(value)])


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if key.pressed and not key.echo:
			if key.keycode == KEY_F9:
				visible = not visible
				_elapsed = 0.0
				refresh()
			elif key.keycode == KEY_F10:
				select_next()
				refresh()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var picked: StringName = _npc_near(canvas.affine_inverse() * click.position)
	if picked != &"":
		selected = picked
		refresh()


## The registered NPC whose body is nearest to `world_pos`, within CLICK_RADIUS; &"" when none is.
func _npc_near(world_pos: Vector2) -> StringName:
	if runtime == null:
		return &""
	var best: StringName = &""
	var best_dist: float = INF
	for npc: StringName in runtime.agents.ids():
		var agent: NpcfAgent2D = runtime.agents.agent(npc)
		var body: CharacterBody2D = agent.body()
		if body == null:
			continue
		var dist: float = body.global_position.distance_to(world_pos)
		if dist <= CLICK_RADIUS and dist < best_dist:
			best = npc
			best_dist = dist
	return best


func _world_ids() -> Array[StringName]:
	if runtime == null or runtime.get_world() == null:
		return []
	return runtime.get_world().npc_ids


## Adds one child item per entry: containers become items with children, scalars become `key: value` leaves.
func _fill_children(parent: TreeItem, value: Variant) -> void:
	if value is Dictionary:
		var dict: Dictionary = value
		var keys: Array = dict.keys()
		keys.sort()
		for key: Variant in keys:
			_add_entry(parent, str(key), dict[key])
	elif value is Array:
		var arr: Array = value
		for i: int in arr.size():
			_add_entry(parent, str(i), arr[i])


func _add_entry(parent: TreeItem, label: String, value: Variant) -> void:
	var item: TreeItem = _tree.create_item(parent)
	if value is Dictionary or value is Array:
		item.set_text(0, label)
		_fill_children(item, value)
	else:
		item.set_text(0, "%s: %s" % [label, str(value)])


func _on_item_collapsed(item: TreeItem) -> void:
	if item.get_parent() == _tree.get_root():
		_open_sections[item.get_text(0)] = not item.collapsed
