extends GdUnitTestSuite
## The 2D adapters with real nodes in the tree: an embodied NPC walks to a room and its arrival is reported
## by the room's area; a freed or re-added agent hands its move back and forth; perception by hearing area
## with a location fallback; and a game-finished action. Movers use no navigation mesh, so walks are straight
## lines and the tests do not depend on navigation map timing. Game ticks are driven by the test, physics runs
## underneath, and every body and room is built here with the toy pack's IDs.

const ROOM: Vector2 = Vector2(160, 120)
const HEARING: float = 96.0
const BODY_LAYER: int = 2
const YARD: Vector2 = Vector2(420, 270)
const WORKSHOP: Vector2 = Vector2(760, 270)
const HOME_B: Vector2 = Vector2(120, 420)

var _runtimes: Array[NpcfRuntime] = []


func after_test() -> void:
	for rt: NpcfRuntime in _runtimes:
		rt.stop()
	_runtimes.clear()


## A runtime in the test tree, started on the toy pack. Decision periods are pushed far past the test, so
## no NPC decides on its own and only the test's actions run.
func _started() -> NpcfRuntime:
	var rt: NpcfRuntime = auto_free(NpcfRuntime.new())
	add_child(rt)
	rt.auto_process = false
	_runtimes.append(rt)
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	for archetype: NpcfArchetypeDef in manifest.archetypes:
		archetype.decision_period_ticks = 1000000
	assert_int(rt.start(manifest, ToyFixture.basic(), 7)).is_equal(OK)
	return rt


func _scene() -> Node2D:
	var scene: Node2D = auto_free(Node2D.new())
	add_child(scene)
	return scene


## A room: a location anchor and an arrival area covering the room, reporting to `rt`.
func _room(scene: Node2D, rt: NpcfRuntime, id: StringName, center: Vector2) -> NpcfLocationArea2D:
	var anchor: NpcfLocationAnchor2D = NpcfLocationAnchor2D.new()
	anchor.location_id = id
	anchor.position = center
	scene.add_child(anchor)
	var area: NpcfLocationArea2D = NpcfLocationArea2D.new()
	area.location_id = id
	area.position = center
	area.collision_mask = BODY_LAYER
	area.runtime_path = rt.get_path()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = ROOM
	shape.shape = rect
	area.add_child(shape)
	scene.add_child(area)
	return area


## An NPC body with its agent, a navigation-free mover and a hearing area. Added to the scene.
func _body(scene: Node2D, rt: NpcfRuntime, id: StringName, at: Vector2) -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.collision_layer = BODY_LAYER
	body.collision_mask = 0
	body.position = at
	var shape: CollisionShape2D = CollisionShape2D.new()
	var disc: CircleShape2D = CircleShape2D.new()
	disc.radius = 8.0
	shape.shape = disc
	body.add_child(shape)
	body.add_child(_agent(rt, id))
	var hearing: NpcfAreaPerception2D = NpcfAreaPerception2D.new()
	hearing.collision_mask = BODY_LAYER
	var ring: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = HEARING
	ring.shape = circle
	hearing.add_child(ring)
	body.add_child(hearing)
	scene.add_child(body)
	return body


## An agent with a navigation-free mover, not yet in a body.
func _agent(rt: NpcfRuntime, id: StringName) -> NpcfAgent2D:
	var agent: NpcfAgent2D = NpcfAgent2D.new()
	agent.npc_id = id
	agent.runtime_path = rt.get_path()
	var mover: NpcfNavMover2D = NpcfNavMover2D.new()
	mover.use_navigation = false
	agent.add_child(mover)
	return agent


func _agent_of(body: CharacterBody2D) -> NpcfAgent2D:
	for child: Node in body.get_children():
		if child is NpcfAgent2D:
			var agent: NpcfAgent2D = child
			return agent
	return null


func _set_location(w: NpcfWorld, npc: StringName, location: StringName) -> void:
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(npc, NpcfFramework.AT, location)]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")


func _walk(w: NpcfWorld, npc: StringName, to: StringName) -> NpcfActionCall:
	var args: Dictionary[StringName, Variant] = {&"location": to}
	var call: NpcfActionCall = NpcfActionCall.make(npc, NpcfFramework.MOVE_TO, args, w.clock.tick)
	assert_str(String(w.executor.start(w, npc, call))).is_equal("ok")
	return call


## Whether this call is the NPC's running action.
func _is_running(w: NpcfWorld, npc: StringName, call: NpcfActionCall) -> bool:
	var ra: NpcfRunningAction = w.npc(npc).running
	return ra != null and ra.call.call_id == call.call_id


## How the call finished. Finishing an action makes its NPC due again, so the NPC may start another action
## after it; the outcome is looked up by the call's ID rather than taken as the NPC's last outcome.
func _outcome(w: NpcfWorld, npc: StringName, call: NpcfActionCall) -> String:
	var list: Array[NpcfActionOutcome] = w.npc(npc).action_outcomes
	var result: String = ""
	for o: NpcfActionOutcome in list:
		if o.call_id == call.call_id and o.outcome != &"started":
			result = String(o.outcome)
	return result


## One game tick, with one physics frame before it so bodies and areas catch up.
func _frame(rt: NpcfRuntime) -> void:
	await get_tree().physics_frame
	rt.advance_frame(1.0 / 60.0)


# --- walking, arrival and handoff ---------------------------------------------------------------

func test_an_embodied_npc_keeps_its_location_until_its_body_enters_the_next_room() -> void:
	var rt: NpcfRuntime = _started()
	var w: NpcfWorld = rt.get_world()
	var scene: Node2D = _scene()
	_room(scene, rt, &"toy.yard", YARD)
	var workshop: NpcfLocationArea2D = _room(scene, rt, &"toy.workshop", WORKSHOP)
	var ana: CharacterBody2D = _body(scene, rt, &"toy.ana", YARD)
	_set_location(w, &"toy.ana", &"toy.yard")
	await get_tree().physics_frame
	await get_tree().physics_frame
	rt.advance_frame(1.0)  # the embodiment and the yard arrival are applied
	var call: NpcfActionCall = _walk(w, &"toy.ana", &"toy.workshop")
	var walked: bool = false
	var frames: int = 0
	while w.location_of(&"toy.ana") != &"toy.workshop" and frames < 3000:
		await get_tree().physics_frame
		rt.advance_frame(1.0 / 60.0)
		frames += 1
		if not workshop.overlaps_body(ana):
			assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.yard")
		if ana.global_position.distance_to(YARD) > 40.0:
			walked = true
	assert_bool(walked).is_true()
	assert_bool(workshop.overlaps_body(ana)).is_true()
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.workshop")
	assert_str(_outcome(w, &"toy.ana", call)).is_equal("success")


func test_freeing_the_agent_mid_path_finishes_the_move_a_full_edge_later() -> void:
	var rt: NpcfRuntime = _started()
	var w: NpcfWorld = rt.get_world()
	var scene: Node2D = _scene()
	_room(scene, rt, &"toy.yard", YARD)
	var workshop: NpcfLocationArea2D = _room(scene, rt, &"toy.workshop", WORKSHOP)
	var ana: CharacterBody2D = _body(scene, rt, &"toy.ana", YARD)
	_set_location(w, &"toy.ana", &"toy.yard")
	await get_tree().physics_frame
	await get_tree().physics_frame
	rt.advance_frame(1.0)
	var call: NpcfActionCall = _walk(w, &"toy.ana", &"toy.workshop")
	for _i: int in 60:
		await _frame(rt)
	assert_bool(workshop.overlaps_body(ana)).is_false()
	# Disembodied between ticks: the 10-tick yard-to-workshop edge starts again from zero.
	var agent: NpcfAgent2D = _agent_of(ana)
	ana.remove_child(agent)
	agent.queue_free()
	for _i: int in 9:
		rt.advance_frame(1.0)
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.yard")
	assert_bool(w.npc(&"toy.ana").is_busy()).is_true()
	rt.advance_frame(1.0)
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.workshop")
	assert_str(_outcome(w, &"toy.ana", call)).is_equal("success")


func test_readding_the_agent_resumes_the_walk_from_the_last_reached_location() -> void:
	var rt: NpcfRuntime = _started()
	var w: NpcfWorld = rt.get_world()
	var scene: Node2D = _scene()
	_room(scene, rt, &"toy.yard", YARD)
	var workshop: NpcfLocationArea2D = _room(scene, rt, &"toy.workshop", WORKSHOP)
	var ana: CharacterBody2D = _body(scene, rt, &"toy.ana", YARD)
	_set_location(w, &"toy.ana", &"toy.yard")
	await get_tree().physics_frame
	await get_tree().physics_frame
	rt.advance_frame(1.0)
	var call: NpcfActionCall = _walk(w, &"toy.ana", &"toy.workshop")
	for _i: int in 30:
		await _frame(rt)
	var old: NpcfAgent2D = _agent_of(ana)
	ana.remove_child(old)
	old.queue_free()
	rt.advance_frame(1.0)
	# Back in the body: the mover receives the remaining path and walks it.
	ana.add_child(_agent(rt, &"toy.ana"))
	rt.advance_frame(1.0)
	var mover: NpcfNavMover2D = _agent_of(ana).mover()
	assert_bool(mover.is_walking()).is_true()
	var frames: int = 0
	while w.location_of(&"toy.ana") != &"toy.workshop" and frames < 3000:
		await _frame(rt)
		frames += 1
	assert_bool(workshop.overlaps_body(ana)).is_true()
	assert_str(String(w.location_of(&"toy.ana"))).is_equal("toy.workshop")
	assert_str(_outcome(w, &"toy.ana", call)).is_equal("success")


# --- perception ---------------------------------------------------------------------------------

func test_an_npc_hears_an_actor_inside_its_hearing_area_at_another_location() -> void:
	var rt: NpcfRuntime = _started()
	var w: NpcfWorld = rt.get_world()
	var scene: Node2D = _scene()
	var bo: CharacterBody2D = _body(scene, rt, &"toy.bo", HOME_B)
	var ana: CharacterBody2D = _body(scene, rt, &"toy.ana", HOME_B + Vector2(30, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var event: NpcfEvent = NpcfEvent.new()
	event.kind = &"toy.chatted"
	event.actors = [&"toy.ana"]
	event.location = &"toy.home_a"
	var view: NpcfEventView = NpcfEventView.new(event)
	# Ana is at home_a, Bo at home_b: the location alone would not carry the event; her body in range does.
	assert_bool(w.adapters.perception.can_perceive(&"toy.bo", view, w.world_view())).is_true()
	ana.position = Vector2(900, 900)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(w.adapters.perception.can_perceive(&"toy.bo", view, w.world_view())).is_false()
	assert_bool(bo.is_inside_tree()).is_true()


func test_an_offscreen_npc_perceives_by_location_only() -> void:
	var rt: NpcfRuntime = _started()
	var w: NpcfWorld = rt.get_world()
	var event: NpcfEvent = NpcfEvent.new()
	event.kind = &"toy.chatted"
	event.actors = [&"toy.ana"]
	event.location = &"toy.home_a"
	var view: NpcfEventView = NpcfEventView.new(event)
	# Cy has no agent: not embodied, so he perceives the event exactly when he is at its location.
	assert_bool(w.adapters.perception.can_perceive(&"toy.cy", view, w.world_view())).is_true()
	assert_bool(w.adapters.perception.can_perceive(&"toy.bo", view, w.world_view())).is_false()


# --- game-finished actions ----------------------------------------------------------------------

func test_a_game_finished_action_runs_until_the_agent_finishes_it() -> void:
	var rt: NpcfRuntime = _started()
	var w: NpcfWorld = rt.get_world()
	var scene: Node2D = _scene()
	var ana: CharacterBody2D = _body(scene, rt, &"toy.ana", YARD)
	var agent: NpcfAgent2D = _agent_of(ana)
	agent.game_finishes_actions = true
	var shown: Array[int] = []
	agent.play_action.connect(func(call_id: int, _action: StringName, _cue: StringName, _ticks: int) -> void:
		shown.append(call_id))
	var call: NpcfActionCall = NpcfActionCall.make(&"toy.ana", &"toy.rest", {}, w.clock.tick)
	assert_str(String(w.executor.start(w, &"toy.ana", call))).is_equal("ok")
	assert_int(shown.size()).is_equal(1)
	for _i: int in 70:  # past toy.rest's 60-tick duration: the game holds the completion
		rt.advance_frame(1.0)
	assert_bool(_is_running(w, &"toy.ana", call)).is_true()
	agent.finish_action(shown[0], true)
	rt.advance_frame(1.0)
	assert_bool(_is_running(w, &"toy.ana", call)).is_false()
	assert_str(_outcome(w, &"toy.ana", call)).is_equal("success")
