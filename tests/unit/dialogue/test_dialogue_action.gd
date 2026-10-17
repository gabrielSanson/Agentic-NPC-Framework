extends GdUnitTestSuite
## A dialogue-tier action named by a generated line (R13.7): it starts through the executor at the next tick, the
## decision selector never considers it, and the rules tier never offers it.

const ANA: StringName = &"toy.ana"
const WAVE: StringName = &"toy.wave"
const VALID_WAVE: String = '{"line":"Give me a moment.","cited_facts":[],"action":{"id":"toy.wave","args":{}}}'

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(transport: NpcfFakeLlmTransport) -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	w.dialogue.generator = NpcfLlmLineGenerator.new(transport)
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.player", NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w


func test_a_generated_action_starts_at_the_next_tick() -> void:
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	transport.replies.append(NpcfLlmReply.make(&"ok", VALID_WAVE, 5))
	var w: NpcfWorld = _world(transport)
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	assert_str(str(w.dialogue.records[0].action)).is_equal("toy.wave")
	assert_str(str(w.view(ANA).running_action())).is_equal("")
	assert_int(w.npc(ANA).action_outcomes.size()).is_equal(0)
	w.step()
	# The wave is one tick long: it started in the inputs phase and succeeded in the actions phase of that step.
	var ran: int = 0
	for o: NpcfActionOutcome in w.npc(ANA).action_outcomes:
		if o.action == WAVE and o.outcome == &"success":
			ran += 1
	assert_int(ran).is_equal(1)


func test_the_decision_selector_never_chose_the_action() -> void:
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	transport.replies.append(NpcfLlmReply.make(&"ok", VALID_WAVE, 5))
	var w: NpcfWorld = _world(transport)
	assert_int(w.dialogue.begin_turn(w, "hello hey", ANA)).is_equal(1)
	w.step()
	w.step()
	for rec: NpcfDecisionRecord in w.npc(ANA).decision_records:
		assert_bool(rec.plan.has(WAVE)).is_false()
		for g: NpcfScoredGoal in rec.scores:
			assert_str(str(g.goal)).is_not_equal(str(WAVE))


func test_the_rules_tier_never_offers_the_dialogue_action() -> void:
	var w: NpcfWorld = _world(NpcfFakeLlmTransport.new())
	var candidates: Array[NpcfActionDef] = [w.pack.action(WAVE)]
	var legal: NpcfLegalActions = w.action_registry.legal_for(w, w.view(ANA), candidates, NpcfActionDef.Tier.RULES)
	assert_array(legal.actions).is_empty()
