extends GdUnitTestSuite
## Action legality: tier, cooldown, preconditions under the NPC's own view, candidate order, and the
## rule that location is not part of legality. Uses the toy pack.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(ToyFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


func _candidates(w: NpcfWorld, ids: Array[StringName]) -> Array[NpcfActionDef]:
	var out: Array[NpcfActionDef] = []
	for id: StringName in ids:
		out.append(w.pack.action(id))
	return out


func test_legal_actions_keep_candidate_order() -> void:
	var w: NpcfWorld = _world()
	var legal: NpcfLegalActions = w.action_registry.legal_for(w, w.view(&"toy.ana"), _candidates(w, [&"toy.work", &"toy.rest"] as Array[StringName]))
	assert_array(legal.ids()).is_equal([&"toy.work", &"toy.rest"])


func test_location_is_not_part_of_legality() -> void:
	var w: NpcfWorld = _world()
	# Ana is at home, far from the workshop, and work is still legal.
	var legal: NpcfLegalActions = w.action_registry.legal_for(w, w.view(&"toy.ana"), _candidates(w, [&"toy.work"] as Array[StringName]))
	assert_bool(legal.has(&"toy.work")).is_true()


func test_tier_filters_actions() -> void:
	var w: NpcfWorld = _world()
	var dialogue: NpcfActionDef = NpcfActionDef.new()
	dialogue.id = &"toy.say"
	dialogue.tier = NpcfActionDef.Tier.DIALOGUE
	var candidates: Array[NpcfActionDef] = [w.pack.action(&"toy.rest"), dialogue]
	var rules: NpcfLegalActions = w.action_registry.legal_for(w, w.view(&"toy.ana"), candidates)
	assert_array(rules.ids()).is_equal([&"toy.rest"])
	var talk: NpcfLegalActions = w.action_registry.legal_for(w, w.view(&"toy.ana"), candidates, NpcfActionDef.Tier.DIALOGUE)
	assert_array(talk.ids()).is_equal([&"toy.say"])


func test_cooldown_hides_an_action_until_it_expires() -> void:
	var w: NpcfWorld = _world()
	var npc: NpcfNpcState = w.npc(&"toy.ana")
	npc.cooldowns[&"toy.rest"] = 10
	var candidates: Array[NpcfActionDef] = [w.pack.action(&"toy.rest")]
	assert_bool(w.action_registry.legal_for(w, w.view(&"toy.ana"), candidates).has(&"toy.rest")).is_false()
	for _i: int in 10:
		w.clock.advance()
	assert_bool(w.action_registry.legal_for(w, w.view(&"toy.ana"), candidates).has(&"toy.rest")).is_true()


func test_precondition_under_the_npcs_view_decides_legality() -> void:
	var w: NpcfWorld = _world()
	var candidates: Array[NpcfActionDef] = [w.pack.action(&"toy.chat")]
	w.clock.start_minute = 480
	assert_bool(w.action_registry.legal_for(w, w.view(&"toy.ana"), candidates).has(&"toy.chat")).is_true()
	w.clock.start_minute = 60
	assert_bool(w.action_registry.legal_for(w, w.view(&"toy.ana"), candidates).has(&"toy.chat")).is_false()
