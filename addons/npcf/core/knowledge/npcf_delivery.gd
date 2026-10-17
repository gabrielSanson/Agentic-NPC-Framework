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
	if not receiver_dependent:
		shared = NpcfBeliefMapper.map(world, e, &"")
	var reacts: bool = world.reactions.has_rules(world, e.kind)
	var metas: Dictionary[int, NpcfBeliefMeta] = {}
	for id: StringName in world.npc_ids:
		if not found.has(id):
			continue
		var npc: NpcfNpcState = world.npc(id)
		var source: int = found[id]
		var facts: Array[NpcfFact] = shared
		if receiver_dependent:
			facts = NpcfBeliefMapper.map(world, e, id)
		if not metas.has(source):
			metas[source] = _meta(world, e, source)
		var meta: NpcfBeliefMeta = metas[source]
		for f: NpcfFact in facts:
			npc.beliefs.put(f, meta)
		if reacts:
			world.reactions.on_delivery(world, id, e, source)


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
