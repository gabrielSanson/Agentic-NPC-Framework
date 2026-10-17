class_name NpcfDelivery
extends RefCounted
## Delivers committed events to NPCs as beliefs (R6.2-R6.4, design "5. Beliefs"). Recipients are
## participants, then witnesses the perception adapter allows, then (for public events) everyone
## else as broadcast. Recipients are handled in sorted ID order.


## Takes the events committed since the last delivery phase and hands each to its recipients.
func deliver_pending(world: NpcfWorld) -> void:
	var batch: Array[NpcfEvent] = world.events.take_undelivered()
	for e: NpcfEvent in batch:
		var ev: NpcfEventView = NpcfEventView.new(e)
		var wv: NpcfWorldView = world.world_view()
		var found: Dictionary[StringName, int] = _found(world, e, ev, wv)
		_deliver(world, e, found)
	world.director.observe(batch)


## Recipients of an event, NPC -> NpcfBelief.Source, in sorted ID order.
func recipients(world: NpcfWorld, e: NpcfEvent) -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = _found(world, e, NpcfEventView.new(e), world.world_view())
	var out: Dictionary[StringName, int] = {}
	var keys: Array[StringName] = []
	keys.assign(found.keys())
	keys.sort_custom(NpcfWorldState.name_less)
	for id: StringName in keys:
		out[id] = found[id]
	return out


## The recipients of an event, unsorted: participants, then witnesses the perception adapter allows,
## then (for public events) everyone else as broadcast.
func _found(world: NpcfWorld, e: NpcfEvent, ev: NpcfEventView, wv: NpcfWorldView) -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for id: StringName in e.actors:
		if world.npc(id) != null:
			found[id] = NpcfBelief.Source.PARTICIPANT
	for id: StringName in e.targets:
		if world.npc(id) != null and not found.has(id):
			found[id] = NpcfBelief.Source.PARTICIPANT
	if e.visibility != NpcfEvent.Visibility.PARTICIPANTS_ONLY:
		for id: StringName in world.adapters.perception.perceivers(ev, wv, found):
			found[id] = NpcfBelief.Source.WITNESSED
	if e.visibility == NpcfEvent.Visibility.PUBLIC:
		for id: StringName in world.npc_ids:
			if not found.has(id):
				found[id] = NpcfBelief.Source.BROADCAST
	return found


## Stores the event's beliefs at each recipient, in sorted ID order (world.npc_ids is sorted, and every
## recipient is an NPC), then runs the reaction rules. Facts are mapped once per event unless a mapper hook
## decides them, and one meta is built per source.
func _deliver(world: NpcfWorld, e: NpcfEvent, found: Dictionary[StringName, int]) -> void:
	var receiver_dependent: bool = NpcfBeliefMapper.depends_on_receiver(world, e)
	var shared: Array[NpcfFact] = []
	var shared_keys: Array[String] = []
	if not receiver_dependent:
		shared = NpcfBeliefMapper.map(world, e, &"")
		shared_keys = _keys(shared)
	var reacts: bool = world.reactions.has_rules(world, e.kind)
	var remembered: bool = e.salience >= world.sim.memory_threshold
	var subjects: Array[StringName] = []
	var params: Dictionary[StringName, Variant] = {}
	var message_key: StringName = e.kind
	if remembered:
		subjects = _subjects(e)
		params = e.payload.duplicate()
		var def: NpcfEventKindDef = world.events.kind_def(e.kind)
		if def != null and def.memory_key != &"":
			message_key = def.memory_key
	var metas: Dictionary[int, NpcfBeliefMeta] = {}
	for id: StringName in world.npc_ids:
		if not found.has(id):
			continue
		var npc: NpcfNpcState = world.npc(id)
		var source: int = found[id]
		var facts: Array[NpcfFact] = shared
		var keys: Array[String] = shared_keys
		if receiver_dependent:
			facts = NpcfBeliefMapper.map(world, e, id)
			keys = _keys(facts)
		if not metas.has(source):
			metas[source] = _meta(world, e, source)
		var meta: NpcfBeliefMeta = metas[source]
		for i: int in facts.size():
			var f: NpcfFact = facts[i]
			if world.audit != null:
				world.audit.on_delivered(id, f.subject, f.fact_id, world.clock.tick)
			npc.beliefs.put_keyed(keys[i], f, meta)
		if remembered:
			npc.memory.append(_record(e, source, subjects, message_key, params))
		if reacts:
			world.reactions.on_delivery(world, id, e, source)
	world.relationships.apply_event_rules(world, e, found)


## The belief-store key of each fact, in the same order as the facts.
static func _keys(facts: Array[NpcfFact]) -> Array[String]:
	var out: Array[String] = []
	for f: NpcfFact in facts:
		out.append(NpcfBeliefStore.key_for(f.subject, f.fact_id))
	return out


## The participants of an event, actors then targets, without duplicates (first occurrence kept).
static func _subjects(e: NpcfEvent) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in e.actors:
		if not out.has(id):
			out.append(id)
	for id: StringName in e.targets:
		if not out.has(id):
			out.append(id)
	return out


## One memory record of a delivered event for one recipient. The subject list and params are shared by every
## recipient of the event; records never change them.
static func _record(e: NpcfEvent, source: int, subjects: Array[StringName], message_key: StringName,
		params: Dictionary[StringName, Variant]) -> NpcfMemoryRecord:
	var r: NpcfMemoryRecord = NpcfMemoryRecord.new()
	r.tick = e.tick
	r.event_id = e.id
	r.kind = e.kind
	r.subjects = subjects
	r.location = e.location
	r.source = source
	r.salience = e.salience
	r.message_key = message_key
	r.params = params
	return r


## Lowers the confidence of told and broadcast beliefs of every NPC by the sim's daily decay.
func decay_beliefs(world: NpcfWorld) -> void:
	var amount: int = world.sim.belief_decay_per_day
	if amount <= 0:
		return
	for id: StringName in world.npc_ids:
		var npc: NpcfNpcState = world.npc(id)
		if npc != null:
			npc.beliefs.decay(amount)


## The provenance a receiver stores with each belief of this event.
func _meta(world: NpcfWorld, e: NpcfEvent, source: int) -> NpcfBeliefMeta:
	var meta: NpcfBeliefMeta = NpcfBeliefMeta.new()
	meta.source = source
	meta.tick = e.tick
	meta.event_id = e.id
	meta.salience = e.salience
	meta.confidence = 100
	if source == NpcfBelief.Source.BROADCAST:
		var def: NpcfEventKindDef = world.events.kind_def(e.kind)
		meta.confidence = def.broadcast_confidence if def != null else 80
	return meta
