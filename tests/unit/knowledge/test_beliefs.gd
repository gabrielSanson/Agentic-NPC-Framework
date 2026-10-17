extends GdUnitTestSuite
## Belief store and the read rule: update rule, default reads, truth for self and public facts,
## confidence gates in conditions, decay and the teller chain cap.

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


func _world(mutate: Callable = Callable()) -> NpcfWorld:
	var pack: NpcfLoadedPack = ToyFixture.load_pack()
	if mutate.is_valid():
		mutate.call(pack)
	var w: NpcfWorld = NpcfWorldBuilder.build(pack, ToyFixture.basic(), 1)
	_worlds.append(w)
	return w


static func _private_fact(pack: NpcfLoadedPack) -> void:
	var mood: NpcfFactDef = NpcfFactDef.new()
	mood.id = &"toy.mood"
	mood.scope = NpcfFactDef.Scope.ENTITY
	mood.value_type = NpcfFactDef.ValueType.BOOL
	mood.default_value = false
	mood.public = false
	pack.facts[mood.id] = mood


func _meta(tick: int, confidence: int, source: int = NpcfBelief.Source.WITNESSED, tellers: Array[StringName] = []) -> NpcfBeliefMeta:
	var m: NpcfBeliefMeta = NpcfBeliefMeta.new()
	m.tick = tick
	m.confidence = confidence
	m.source = source
	m.tellers = tellers
	return m


func _fact(value: Variant) -> NpcfFact:
	return NpcfFact.make(&"toy.ana", &"toy.mood", value)


func test_later_tick_replaces_the_belief() -> void:
	var store: NpcfBeliefStore = NpcfBeliefStore.new()
	assert_bool(store.put(_fact(true), _meta(5, 100))).is_true()
	assert_bool(store.put(_fact(false), _meta(4, 100))).is_false()
	assert_bool(store.put(_fact(false), _meta(6, 10))).is_true()
	var b: NpcfBelief = store.get_belief(&"toy.ana", &"toy.mood")
	assert_bool(b.value).is_false()
	assert_int(b.tick).is_equal(6)


func test_equal_tick_keeps_the_more_confident_belief() -> void:
	var store: NpcfBeliefStore = NpcfBeliefStore.new()
	store.put(_fact(true), _meta(6, 60))
	assert_bool(store.put(_fact(false), _meta(6, 80))).is_true()
	assert_bool(store.get_belief(&"toy.ana", &"toy.mood").value).is_false()
	assert_bool(store.put(_fact(true), _meta(6, 50))).is_false()
	assert_bool(store.put(_fact(true), _meta(6, 80))).is_false()
	assert_bool(store.get_belief(&"toy.ana", &"toy.mood").value).is_false()


func test_missing_belief_reads_as_default_with_zero_confidence() -> void:
	var w: NpcfWorld = _world(_private_fact)
	assert_object(w.npc(&"toy.bo").beliefs.get_belief(&"toy.ana", &"toy.mood")).is_null()
	var read: NpcfFactRead = w.view(&"toy.bo").fact(&"toy.ana", &"toy.mood")
	assert_bool(read.value).is_false()
	assert_int(read.confidence).is_equal(0)
	assert_int(read.source).is_equal(NpcfBelief.Source.DEFAULT)


func test_self_and_public_facts_read_truth() -> void:
	var w: NpcfWorld = _world(_private_fact)
	w.state.write(&"toy.bo", &"toy.mood", true)
	var own: NpcfFactRead = w.view(&"toy.bo").fact(&"toy.bo", &"toy.mood")
	assert_bool(own.value).is_true()
	assert_int(own.confidence).is_equal(100)
	assert_int(own.source).is_equal(NpcfBelief.Source.TRUTH)
	var public: NpcfFactRead = w.view(&"toy.bo").fact(&"toy.home_a", &"toy.safe")
	assert_bool(public.value).is_true()
	assert_int(public.source).is_equal(NpcfBelief.Source.TRUTH)


func test_belief_below_min_confidence_makes_a_fact_condition_false() -> void:
	var w: NpcfWorld = _world(_private_fact)
	var c: NpcfConditionDef = NpcfConditionDef.new()
	c.op_kind = NpcfConditionDef.OpKind.FACT
	c.subject_from = NpcfConditionDef.SubjectFrom.ARG
	c.arg = &"who"
	c.fact = w.pack.facts[&"toy.mood"]
	c.compare = NpcfConditionDef.Compare.EQ
	c.value = true
	c.min_confidence = 50
	var args: Dictionary[StringName, Variant] = {&"who": &"toy.ana"}
	var bo: NpcfNpcState = w.npc(&"toy.bo")
	bo.beliefs.put(_fact(true), _meta(1, 40))
	assert_bool(NpcfConditions.check(w, w.view(&"toy.bo"), c, args)).is_false()
	bo.beliefs.put(_fact(true), _meta(2, 60))
	assert_bool(NpcfConditions.check(w, w.view(&"toy.bo"), c, args)).is_true()


func test_decay_floors_at_zero_and_spares_witnessed_and_participant_beliefs() -> void:
	var store: NpcfBeliefStore = NpcfBeliefStore.new()
	store.put(NpcfFact.make(&"toy.ana", &"toy.a", 1), _meta(1, 5, NpcfBelief.Source.TOLD_BY))
	store.put(NpcfFact.make(&"toy.ana", &"toy.b", 1), _meta(1, 80, NpcfBelief.Source.BROADCAST))
	store.put(NpcfFact.make(&"toy.ana", &"toy.c", 1), _meta(1, 80, NpcfBelief.Source.WITNESSED))
	store.put(NpcfFact.make(&"toy.ana", &"toy.d", 1), _meta(1, 80, NpcfBelief.Source.PARTICIPANT))
	store.decay(10)
	assert_int(store.get_belief(&"toy.ana", &"toy.a").confidence).is_equal(0)
	assert_int(store.get_belief(&"toy.ana", &"toy.b").confidence).is_equal(70)
	assert_int(store.get_belief(&"toy.ana", &"toy.c").confidence).is_equal(80)
	assert_int(store.get_belief(&"toy.ana", &"toy.d").confidence).is_equal(80)


func test_world_daily_decay_uses_the_sim_setting() -> void:
	var w: NpcfWorld = _world()
	w.npc(&"toy.ana").beliefs.put(NpcfFact.make(&"toy.ana", &"toy.a", 1), _meta(1, 50, NpcfBelief.Source.BROADCAST))
	w.delivery.decay_beliefs(w)
	assert_int(w.npc(&"toy.ana").beliefs.get_belief(&"toy.ana", &"toy.a").confidence).is_equal(50 - w.sim.belief_decay_per_day)


func test_teller_chain_is_capped_and_keeps_the_newest() -> void:
	var store: NpcfBeliefStore = NpcfBeliefStore.new()
	var chain: Array[StringName] = [&"toy.t1", &"toy.t2", &"toy.t3", &"toy.t4", &"toy.t5", &"toy.t6"]
	store.put(_fact(true), _meta(1, 50, NpcfBelief.Source.TOLD_BY, chain))
	var b: NpcfBelief = store.get_belief(&"toy.ana", &"toy.mood")
	assert_int(NpcfBelief.MAX_TELLERS).is_equal(4)
	assert_array(b.tellers).is_equal([&"toy.t1", &"toy.t2", &"toy.t3", &"toy.t4"])
