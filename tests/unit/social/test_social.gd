extends GdUnitTestSuite
## Social state: relationship values are clamped and carry their cause, defaults come from archetypes and
## scenario seeds, delta rules fire on delivery, tag transitions emit one event per real change, rumors move
## beliefs with a period limit and the same-teller rule, and player events reach witnesses.

const TRUST: StringName = &"toy.trust"
const LIKING: StringName = &"toy.liking"

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## The toy world with Ana, Bo and Cy (Ana and Cy at home_a, Bo at home_b).
func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _rel_change(holder: StringName, other: StringName, dim: StringName, amount: int) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = NpcfStateChange.Kind.REL_DELTA
	c.subject = holder
	c.other = other
	c.dim = dim
	c.amount = amount
	return c


func _emit(w: NpcfWorld, kind: StringName, location: StringName, actors: Array[StringName]) -> void:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = kind
	e.location = location
	e.actors = actors
	w.emit(e)


func _share(w: NpcfWorld, speaker: StringName, listeners: Array[StringName]) -> int:
	return w.rumors.share(w, speaker, listeners, w.clock.tick)


func _sighting(w: NpcfWorld, id: StringName) -> NpcfBelief:
	return w.npc(id).beliefs.get_belief(&"toy.home_a", &"toy.sighting")


func test_changes_are_clamped_and_record_their_cause() -> void:
	var w: NpcfWorld = _world()
	var ana: StringName = &"toy.ana"
	var bo: StringName = &"toy.bo"
	var up: Array[NpcfStateChange] = [_rel_change(ana, bo, TRUST, 150)] as Array[NpcfStateChange]
	assert_str(w.applier.apply(w, up, 42)).is_equal("")
	assert_int(w.relationships.value(w, ana, bo, TRUST)).is_equal(100)
	assert_int(w.relationships.last_cause(ana, bo, TRUST)).is_equal(42)
	var last: NpcfRelChange = w.relationships.changes.back()
	assert_int(last.old_value).is_equal(0)
	assert_int(last.new_value).is_equal(100)
	var down: Array[NpcfStateChange] = [_rel_change(ana, bo, TRUST, -250)] as Array[NpcfStateChange]
	assert_str(w.applier.apply(w, down, 43)).is_equal("")
	assert_int(w.relationships.value(w, ana, bo, TRUST)).is_equal(-100)


func test_unset_pairs_read_archetype_default_then_dimension_default() -> void:
	var w: NpcfWorld = _world()
	var ana: StringName = &"toy.ana"
	var cy: StringName = &"toy.cy"
	assert_int(w.relationships.value(w, ana, cy, TRUST)).is_equal(0)
	w.npc(ana).resolved.rel_defaults[TRUST] = 10
	assert_int(w.relationships.value(w, ana, cy, TRUST)).is_equal(10)
	assert_str(String(w.relationships.band(w, ana, cy, TRUST))).is_equal("toy.neutral")
	w.npc(ana).resolved.rel_defaults[TRUST] = 40
	assert_str(String(w.relationships.band(w, ana, cy, TRUST))).is_equal("toy.trusting")


func test_scenario_seed_sets_a_starting_value_without_a_cause() -> void:
	var s: NpcfScenarioDef = ToyFixture.basic()
	var ana: NpcfCharacterDef = null
	var bo: NpcfCharacterDef = null
	for entry: NpcfCastEntry in s.cast:
		if entry.character.id == &"toy.ana":
			ana = entry.character
		if entry.character.id == &"toy.bo":
			bo = entry.character
	var seed_rel: NpcfRelSeed = NpcfRelSeed.new()
	seed_rel.from_character = ana
	seed_rel.to_character = bo
	seed_rel.values = {LIKING: 35}
	s.relationships = [seed_rel] as Array[NpcfRelSeed]
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), s, 1)
	_worlds.append(w)
	assert_int(w.relationships.value(w, &"toy.ana", &"toy.bo", LIKING)).is_equal(35)
	assert_str(String(w.relationships.band(w, &"toy.ana", &"toy.bo", LIKING))).is_equal("toy.warm")
	assert_int(w.relationships.last_cause(&"toy.ana", &"toy.bo", LIKING)).is_equal(-1)


func test_delta_rule_moves_witnesses_toward_the_speaker() -> void:
	var w: NpcfWorld = _world()
	_emit(w, &"toy.chatted", &"toy.home_a", [&"toy.ana"] as Array[StringName])
	w.step()
	assert_int(w.relationships.value(w, &"toy.cy", &"toy.ana", LIKING)).is_equal(2)
	assert_int(w.relationships.value(w, &"toy.ana", &"toy.ana", LIKING)).is_equal(0)
	assert_int(w.relationships.value(w, &"toy.bo", &"toy.ana", LIKING)).is_equal(0)


func test_tag_transitions_emit_one_event_per_real_change() -> void:
	var w: NpcfWorld = _world()
	var ana: StringName = &"toy.ana"
	var energy: NpcfNeedDef = w.pack.need(&"toy.energy")
	w.need_system.set_need(w, ana, energy.id, 150, true)
	w.step()
	assert_bool(w.npc(ana).has_tag(&"toy.weary")).is_true()
	assert_int(_tag_events(w, ana, &"toy.weary", true)).is_equal(1)
	w.need_system.set_need(w, ana, energy.id, 600, true)
	w.step()
	assert_bool(w.npc(ana).has_tag(&"toy.weary")).is_false()
	assert_int(_tag_events(w, ana, &"toy.weary", false)).is_equal(1)
	var before: int = w.events.log.size()
	w.step()
	assert_int(_tag_events_since(w, before, ana)).is_equal(0)


## Counts npcf.tags_changed events of this tick for one NPC, tag and direction.
func _tag_events(w: NpcfWorld, npc: StringName, tag: StringName, added: bool) -> int:
	var count: int = 0
	for e: NpcfEvent in w.events.log:
		if e.tick != w.clock.tick or e.kind != NpcfFramework.TAGS_CHANGED or not e.actors.has(npc):
			continue
		if e.payload.get(&"tag") == tag and e.payload.get(&"added") == added:
			count += 1
	return count


func _tag_events_since(w: NpcfWorld, from_index: int, npc: StringName) -> int:
	var count: int = 0
	for i: int in range(from_index, w.events.log.size()):
		var e: NpcfEvent = w.events.log[i]
		if e.kind == NpcfFramework.TAGS_CHANGED and e.actors.has(npc):
			count += 1
	return count


func test_rumor_moves_a_belief_to_a_listener_at_the_same_place() -> void:
	var w: NpcfWorld = _world()
	_emit(w, &"toy.spotted", &"toy.home_a", [] as Array[StringName])
	w.step()
	# Bo walks in quietly: the listener is now at the speaker's location.
	w.applier.apply(w, [NpcfStateChange.set_fact(&"toy.bo", NpcfFramework.AT, &"toy.home_a")] as Array[NpcfStateChange], -1, true)
	var stored: int = _share(w, &"toy.ana", [&"toy.bo", &"toy.cy"] as Array[StringName])
	# Cy already holds the same belief from the same tick at confidence 100, so only Bo stores it.
	assert_int(stored).is_equal(1)
	var b: NpcfBelief = _sighting(w, &"toy.bo")
	assert_object(b).is_not_null()
	if b == null:
		return
	assert_bool(b.value).is_true()
	assert_int(b.confidence).is_equal(80)
	assert_int(b.source).is_equal(NpcfBelief.Source.TOLD_BY)
	assert_str(String(b.teller)).is_equal("toy.ana")


func _spread_setup() -> NpcfWorld:
	var w: NpcfWorld = _world()
	_emit(w, &"toy.spotted", &"toy.home_a", [] as Array[StringName])
	w.step()
	w.applier.apply(w, [NpcfStateChange.set_fact(&"toy.bo", NpcfFramework.AT, &"toy.home_a")] as Array[NpcfStateChange], -1, true)
	return w


func test_share_period_limit_then_window_reopens() -> void:
	var w: NpcfWorld = _spread_setup()
	var listeners: Array[StringName] = [&"toy.bo", &"toy.cy"]
	var start: int = w.clock.tick
	assert_int(_share(w, &"toy.ana", listeners)).is_equal(1)
	assert_int(_share(w, &"toy.ana", listeners)).is_greater_equal(0)
	assert_int(_share(w, &"toy.ana", listeners)).is_equal(0)
	# Ana learns something new a period later; the window has reopened, so she may share it to Bo.
	var meta: NpcfBeliefMeta = NpcfBeliefMeta.new()
	meta.source = NpcfBelief.Source.WITNESSED
	meta.tick = start + 60
	meta.salience = 60
	meta.confidence = 100
	w.npc(&"toy.ana").beliefs.put(NpcfFact.make(&"toy.home_b", &"toy.sighting", true), meta)
	assert_int(w.rumors.share(w, &"toy.ana", [&"toy.bo"] as Array[StringName], start + 60)).is_equal(1)
	assert_object(w.npc(&"toy.bo").beliefs.get_belief(&"toy.home_b", &"toy.sighting")).is_not_null()


func test_same_teller_rule_keeps_confidence_and_a_new_teller_wins() -> void:
	var w: NpcfWorld = _spread_setup()
	var listeners: Array[StringName] = [&"toy.bo", &"toy.cy"]
	var start: int = w.clock.tick
	_share(w, &"toy.ana", listeners)
	w.npc(&"toy.bo").beliefs.decay(10)
	assert_int(_sighting(w, &"toy.bo").confidence).is_equal(70)
	w.rumors.share(w, &"toy.ana", [&"toy.bo"] as Array[StringName], start + 60)
	assert_int(_sighting(w, &"toy.bo").confidence).is_equal(70)
	w.rumors.share(w, &"toy.cy", [&"toy.bo"] as Array[StringName], start + 60)
	var b: NpcfBelief = _sighting(w, &"toy.bo")
	assert_int(b.confidence).is_equal(80)
	assert_str(String(b.teller)).is_equal("toy.cy")


func _tie_break_subject(seed_value: int) -> String:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), seed_value)
	_worlds.append(w)
	# Two shareable beliefs with equal salience and tick: the rumor RNG must pick between them.
	var meta: NpcfBeliefMeta = NpcfBeliefMeta.new()
	meta.source = NpcfBelief.Source.WITNESSED
	meta.tick = w.clock.tick
	meta.salience = 60
	meta.confidence = 100
	var ana: NpcfNpcState = w.npc(&"toy.ana")
	ana.beliefs.put(NpcfFact.make(&"toy.home_a", &"toy.sighting", true), meta)
	ana.beliefs.put(NpcfFact.make(&"toy.yard", &"toy.sighting", true), meta)
	w.rumors.share(w, &"toy.ana", [&"toy.bo"] as Array[StringName], w.clock.tick)
	var bo: NpcfNpcState = w.npc(&"toy.bo")
	var got_home: bool = bo.beliefs.get_belief(&"toy.home_a", &"toy.sighting") != null
	var got_yard: bool = bo.beliefs.get_belief(&"toy.yard", &"toy.sighting") != null
	assert_bool(got_home != got_yard).is_true()
	return "home_a" if got_home else "yard"


func test_rumor_tie_break_is_deterministic_for_a_seed() -> void:
	var first: String = _tie_break_subject(1)
	var second: String = _tie_break_subject(1)
	assert_str(first).is_equal(second)


func test_player_event_reaches_witnesses_and_changes_their_view_of_the_player() -> void:
	var w: NpcfWorld = _world()
	# A test-only rule: witnesses of a spotting trust the player a little more. The social definition is copied so
	# the cached pack resource is not changed for other tests.
	w.pack.social = w.pack.social.duplicate() as NpcfSocialDef
	var rule: NpcfRelDeltaRule = NpcfRelDeltaRule.new()
	rule.event_kind = w.pack.event_kind(&"toy.spotted")
	rule.from_role = NpcfRelDeltaRule.Role.WITNESS
	rule.to_role = NpcfRelDeltaRule.Role.ACTOR_0
	rule.dim = w.pack.rel_dims[TRUST]
	rule.delta = 5
	w.pack.social.delta_rules.append(rule)
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = &"toy.spotted"
	e.actors = [&"toy.player"] as Array[StringName]
	e.location = &"toy.home_a"
	w.queue_input(NpcfInput.event_input(e))
	w.step()
	w.step()
	for id: StringName in [&"toy.ana", &"toy.cy"]:
		var n: NpcfNpcState = w.npc(id)
		var found: bool = false
		for r: NpcfMemoryRecord in n.memory.records:
			if r.kind == &"toy.spotted" and r.subjects.has(&"toy.player"):
				found = true
		assert_bool(found).override_failure_message(String(id) + " has no memory of the player").is_true()
		assert_int(w.relationships.value(w, id, &"toy.player", TRUST)).override_failure_message(String(id)).is_equal(5)


func test_relationship_input_reads_the_player_or_the_best_neighbour_at_the_location() -> void:
	var w: NpcfWorld = _world()
	var ana: StringName = &"toy.ana"
	var player: StringName = w.sim.player_entity
	var toward_player: NpcfConsiderationDef = NpcfConsiderationDef.new()
	toward_player.input = NpcfConsiderationDef.InputKind.RELATIONSHIP
	toward_player.dim = TRUST
	toward_player.subject_from = NpcfConditionDef.SubjectFrom.PLAYER
	w.relationships.seed_value(w, ana, player, TRUST, 50)
	assert_float(w.scorer.input(w, w.view(ana), toward_player, &"")).is_equal_approx(0.75, 0.000001)
	var best_here: NpcfConsiderationDef = NpcfConsiderationDef.new()
	best_here.input = NpcfConsiderationDef.InputKind.RELATIONSHIP
	best_here.dim = TRUST
	best_here.subject_from = NpcfConditionDef.SubjectFrom.SELF
	w.relationships.seed_value(w, ana, &"toy.cy", TRUST, 50)
	# Bo is at home_b, not with Ana, so his 100 does not count.
	w.relationships.seed_value(w, ana, &"toy.bo", TRUST, 100)
	assert_float(w.scorer.input(w, w.view(ana), best_here, &"")).is_equal_approx(0.75, 0.000001)
