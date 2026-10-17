extends GdUnitTestSuite
## The knowledge-boundary audit (C5c 5.4, R6.6): a long dialogue run reads only what the NPCs were told, and a belief
## injected without delivery is caught when the NPC decides on it.

const ANA: StringName = &"toy.ana"
const SIGHTING: String = "res://packs/toy/facts/sighting.tres"
const THREE_DAYS: int = 4320
const TURN_EVERY: int = 240
const VALID: String = '{"line":"Hi there, friend.","cited_facts":[],"action":null}'

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(world_seed: int) -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), world_seed)
	_worlds.append(w)
	w.audit = NpcfKnowledgeAudit.new()
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.player", NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w


## Reads happen on the decision and prompt paths only, so the line generator runs (prompts are built, the fake
## transport answers every turn with a valid line).
## The player walks to Ana's location before each scripted turn (the test places the player; the simulation does not),
## so every turn is audible and builds a prompt.
func _say(w: NpcfWorld) -> int:
	var here: StringName = w.location_of(ANA)
	if here == &"":
		return 0
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.player", NpcfFramework.AT, here)]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w.dialogue.begin_turn(w, "any news seen", ANA)


func test_toy_three_days_has_no_violations() -> void:
	var w: NpcfWorld = _world(9)
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	for _i: int in THREE_DAYS / TURN_EVERY + 1:
		transport.replies.append(NpcfLlmReply.make(&"ok", VALID, 5))
	w.dialogue.generator = NpcfLlmLineGenerator.new(transport)
	var turns: int = 0
	for t: int in THREE_DAYS:
		if t > 0 and t % TURN_EVERY == 0 and _say(w) > 0:
			turns += 1
		w.step()
	assert_int(turns).is_greater(0)
	var audit: NpcfKnowledgeAudit = w.audit
	assert_int(audit.reads.size()).is_greater(0)
	assert_array(audit.violations(w)).is_empty()


func test_injected_fact_is_caught() -> void:
	var w: NpcfWorld = _world(9)
	for _t: int in 300:
		w.step()
	# A belief about the player's non-public sighting, put straight into Ana's store with no delivery.
	var meta: NpcfBeliefMeta = NpcfBeliefMeta.new()
	meta.source = NpcfBelief.Source.WITNESSED
	meta.tick = w.clock.tick
	meta.confidence = 100
	var sighting: NpcfFactDef = ResourceLoader.load(SIGHTING, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfFactDef
	assert_bool(sighting != null and not sighting.public).is_true()
	var ana: NpcfNpcState = w.npc(ANA)
	ana.beliefs.put(NpcfFact.make(&"toy.player", sighting.id, true), meta)
	# A test-only goal whose one consideration reads that fact through the decision's read rule.
	var consideration: NpcfConsiderationDef = NpcfConsiderationDef.new()
	consideration.id = &"test.sighting"
	consideration.input = NpcfConsiderationDef.InputKind.FACT
	consideration.fact = sighting
	consideration.subject_from = NpcfConditionDef.SubjectFrom.PLAYER
	var goal: NpcfGoalDef = NpcfGoalDef.new()
	goal.id = &"test.snoop"
	goal.considerations = [consideration]
	ana.resolved.goals.append(goal)
	w.scheduler.mark_due(w, ANA, &"test", true)
	w.step()
	var found: Array[String] = w.audit.violations(w)
	assert_array(found).is_not_empty()
	var text: String = "\n".join(PackedStringArray(found))
	assert_str(text).contains("toy.ana")
	assert_str(text).contains("toy.sighting")
