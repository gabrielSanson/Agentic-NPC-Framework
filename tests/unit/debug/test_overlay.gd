extends GdUnitTestSuite
## The debug overlay (C5d): the add rule for the four flag combinations, the runtime adds a hidden overlay and removes it
## on stop, NPC selection and the trace tree (top-level sections collapsed), and F9 toggling.

var _runtimes: Array[NpcfRuntime] = []


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()


## A runtime in the test tree with its frames driven by the test.
func _runtime() -> NpcfRuntime:
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	_runtimes.append(rt)
	return rt


## A running runtime on the toy pack and the basic scenario.
func _started() -> NpcfRuntime:
	var rt: NpcfRuntime = _runtime()
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	return rt


func _overlay_of(rt: NpcfRuntime) -> NpcfDebugOverlay:
	return rt.get_node_or_null(^"NpcfDebugOverlay") as NpcfDebugOverlay


func _key(keycode: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func test_should_add() -> void:
	assert_bool(NpcfDebugOverlay.should_add(false, false)).is_false()
	assert_bool(NpcfDebugOverlay.should_add(true, false)).is_true()
	assert_bool(NpcfDebugOverlay.should_add(false, true)).is_true()
	assert_bool(NpcfDebugOverlay.should_add(true, true)).is_true()


func test_runtime_adds_overlay_in_debug() -> void:
	var rt: NpcfRuntime = _started()
	var overlay: NpcfDebugOverlay = _overlay_of(rt)
	assert_object(overlay).is_not_null()
	assert_bool(overlay.visible).is_false()
	rt.stop()
	assert_object(_overlay_of(rt)).is_null()


func test_select_next_and_refresh() -> void:
	var rt: NpcfRuntime = _started()
	var overlay: NpcfDebugOverlay = _overlay_of(rt)
	var ids: Array[StringName] = rt.get_world().npc_ids
	assert_bool(ids.is_empty()).is_false()
	overlay.select_next()
	assert_str(str(overlay.selected)).is_equal(str(ids[0]))
	overlay.refresh()
	var trees: Array[Node] = overlay.find_children("*", "Tree", true, false)
	assert_int(trees.size()).is_equal(1)
	var tree: Tree = trees[0] as Tree
	var needs: TreeItem = null
	var item: TreeItem = tree.get_root().get_first_child()
	while item != null:
		if item.get_text(0) == "needs":
			needs = item
		item = item.get_next()
	assert_object(needs).is_not_null()
	assert_bool(needs.collapsed).is_true()


func test_f9_toggles() -> void:
	var rt: NpcfRuntime = _started()
	var overlay: NpcfDebugOverlay = _overlay_of(rt)
	overlay._unhandled_input(_key(KEY_F9))
	assert_bool(overlay.visible).is_true()
	overlay._unhandled_input(_key(KEY_F9))
	assert_bool(overlay.visible).is_false()
