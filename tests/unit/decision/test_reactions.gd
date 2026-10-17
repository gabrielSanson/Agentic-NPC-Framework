extends GdUnitTestSuite
## Reactions: a delivered event adds a personal directive and bypasses hysteresis on the next decision,
## respects the per-NPC cooldown, reacts only to witnesses and participants when witnessed_only is set,
## and checks its condition on the receiver's view.

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


func _rule(w: NpcfWorld, kind: StringName, witnessed_only: bool, priority: float) -> NpcfReactionRuleDef:
	var goal: NpcfGoalDef = NpcfGoalDef.new()
	goal.id = &"x.talk"
	var rule: NpcfReactionRuleDef = NpcfReactionRuleDef.new()
	rule.id = &"x.react"
	rule.event_kind = w.pack.event_kind(kind)
	rule.witnessed_only = witnessed_only
	rule.goal = goal
	rule.priority = priority
	rule.duration_ticks = 30
	rule.cooldown_ticks = 60
	w.pack.reactions.append(rule)
	return rule


func _chat(w: NpcfWorld, actor: StringName) -> void:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = &"toy.chatted"
	e.actors = [actor]
	e.location = w.location_of(actor)
	w.emit(e)
	w.delivery.deliver_pending(w)


func _talk_directives(w: NpcfWorld) -> Array[NpcfDirective]:
	var out: Array[NpcfDirective] = []
	for d: NpcfDirective in w.directives.active():
		if d.goal == &"x.talk":
			out.append(d)
	return out


func test_participant_and_witnesses_get_a_personal_directive() -> void:
	var w: NpcfWorld = _world()
	_rule(w, &"toy.chatted", true, 0.5)
	_chat(w, &"toy.ana")
	var targets: Array[StringName] = []
	for d: NpcfDirective in _talk_directives(w):
		targets.append(d.target_npc)
		assert_str(String(d.origin)).is_equal("x.react")
		assert_float(d.priority).is_equal_approx(0.5, 0.000001)
		assert_int(d.expires_tick).is_equal(w.clock.tick + 30)
	# Ana is the participant; Cy is in her location and witnesses it. Bo is at home_b and does not.
	assert_array(targets).contains_exactly([&"toy.ana", &"toy.cy"])


func test_witnessed_only_ignores_broadcast_events() -> void:
	var w: NpcfWorld = _world()
	_rule(w, NpcfFramework.FACT_CHANGED, true, 0.5)
	w.applier.apply(w, [NpcfStateChange.add_fact(NpcfFramework.GLOBAL, &"toy.discoveries", 1)] as Array[NpcfStateChange], -1)
	w.delivery.deliver_pending(w)
	assert_array(_talk_directives(w)).is_empty()


func test_without_witnessed_only_broadcast_reaches_everyone() -> void:
	var w: NpcfWorld = _world()
	_rule(w, NpcfFramework.FACT_CHANGED, false, 0.5)
	w.applier.apply(w, [NpcfStateChange.add_fact(NpcfFramework.GLOBAL, &"toy.discoveries", 1)] as Array[NpcfStateChange], -1)
	w.delivery.deliver_pending(w)
	assert_int(_talk_directives(w).size()).is_equal(w.npc_ids.size())


func test_reaction_cooldown_per_npc() -> void:
	var w: NpcfWorld = _world()
	_rule(w, &"toy.chatted", true, 0.5)
	_chat(w, &"toy.ana")
	assert_int(_talk_directives(w).size()).is_equal(2)
	for _i: int in 10:
		w.clock.advance()
	_chat(w, &"toy.ana")
	assert_int(_talk_directives(w).size()).is_equal(2)
	for _i: int in 60:
		w.clock.advance()
	_chat(w, &"toy.ana")
	assert_int(_talk_directives(w).size()).is_equal(4)


func test_reaction_condition_is_checked_on_the_receivers_view() -> void:
	var w: NpcfWorld = _world()
	var rule: NpcfReactionRuleDef = _rule(w, &"toy.chatted", true, 0.5)
	var energy_low: NpcfConditionDef = NpcfConditionDef.new()
	energy_low.op_kind = NpcfConditionDef.OpKind.NEED
	energy_low.need = w.pack.need(&"toy.energy")
	energy_low.compare = NpcfConditionDef.Compare.LT
	energy_low.value = 500
	rule.condition = energy_low
	_chat(w, &"toy.ana")
	# Ana's energy is 700, so the condition fails for everyone.
	assert_array(_talk_directives(w)).is_empty()


func test_reaction_bypasses_hysteresis_on_the_next_decision() -> void:
	var w: NpcfWorld = _world()
	var rule: NpcfReactionRuleDef = _rule(w, &"toy.chatted", true, 0.02)
	var rest_a: NpcfGoalDef = _rest_goal(w, &"x.a", 1.0)
	var talk: NpcfGoalDef = rule.goal
	talk.weight = 1.0
	talk.candidate_actions = [w.pack.action(&"toy.rest")] as Array[NpcfActionDef]
	var n: NpcfNpcState = w.npc(&"toy.bo")
	n.resolved.goals.clear()
	n.resolved.goals.append(rest_a)
	n.resolved.goals.append(talk)
	n.current_goal = &"x.a"

	# Equal utility: x.a wins the tie by ID and is kept. Bo starts its rest.
	var first: NpcfDecisionRecord = w.selector.decide(w, &"toy.bo")
	assert_str(String(first.chosen_goal)).is_equal("x.a")
	assert_bool(n.is_busy()).is_true()

	# The reaction adds a 2 percent directive bonus, which is inside the 10 percent hysteresis. Without a
	# taken bypass entry the decision keeps x.a.
	_chat(w, &"toy.bo")
	var blocked: NpcfDecisionRecord = w.selector.decide(w, &"toy.bo")
	assert_str(String(blocked.chosen_goal)).is_equal("x.a")
	assert_bool(blocked.hysteresis_blocked).is_true()

	# Once the reaction's due entry is taken, the decision bypasses hysteresis and switches.
	w.scheduler.take_due(w, 10)
	var record: NpcfDecisionRecord = w.selector.decide(w, &"toy.bo")
	assert_str(String(record.chosen_goal)).is_equal("x.talk")
	assert_str(String(record.reaction_rule)).is_equal("x.react")
	assert_str(String(record.reason)).is_equal("reaction")
	assert_str(String(n.current_goal)).is_equal("x.talk")


func _rest_goal(w: NpcfWorld, id: StringName, weight: float) -> NpcfGoalDef:
	var g: NpcfGoalDef = NpcfGoalDef.new()
	g.id = id
	g.weight = weight
	g.candidate_actions = [w.pack.action(&"toy.rest")] as Array[NpcfActionDef]
	return g
