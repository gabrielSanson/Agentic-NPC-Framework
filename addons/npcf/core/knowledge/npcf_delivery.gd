class_name NpcfDelivery
extends RefCounted
## Delivers committed events to NPCs as beliefs (R6.2-R6.4, design "5. Beliefs"). Recipients are
## participants, then witnesses the perception adapter allows, then (for public events) everyone
## else as broadcast. Recipients are handled in sorted ID order.


## Takes the events committed since the last delivery phase and hands each to its recipients.
func deliver_pending(world: NpcfWorld) -> void:
	var batch: Array[NpcfEvent] = world.events.take_undelivered()
	for e: NpcfEvent in batch:
		var recips: Dictionary[StringName, int] = recipients(world, e)
		var ids: Array[StringName] = []
		ids.assign(recips.keys())
		ids.sort_custom(NpcfWorldState.name_less)
		for id: StringName in ids:
			var npc: NpcfNpcState = world.npc(id)
			if npc == null:
				continue
			var source: int = recips[id]
			var facts: Array[NpcfFact] = NpcfBeliefMapper.map(world, e, id)
			var meta: NpcfBeliefMeta = _meta(world, e, source)
			for f: NpcfFact in facts:
				npc.beliefs.put(f, meta)
			world.reactions.on_delivery(world, id, e, source)


## Recipients of an event, NPC -> NpcfBelief.Source, in sorted ID order.
func recipients(world: NpcfWorld, e: NpcfEvent) -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for id: StringName in e.actors:
		if world.npc(id) != null:
			found[id] = NpcfBelief.Source.PARTICIPANT
	for id: StringName in e.targets:
		if world.npc(id) != null and not found.has(id):
			found[id] = NpcfBelief.Source.PARTICIPANT
	var wv: NpcfWorldView = world.world_view()
	if e.visibility != NpcfEvent.Visibility.PARTICIPANTS_ONLY:
		for id: StringName in world.npc_ids:
			if found.has(id):
				continue
			if world.adapters.perception.can_perceive(id, NpcfEventView.new(e), wv):
				found[id] = NpcfBelief.Source.WITNESSED
	if e.visibility == NpcfEvent.Visibility.PUBLIC:
		for id: StringName in world.npc_ids:
			if not found.has(id):
				found[id] = NpcfBelief.Source.BROADCAST
	var out: Dictionary[StringName, int] = {}
	var keys: Array[StringName] = []
	keys.assign(found.keys())
	keys.sort_custom(NpcfWorldState.name_less)
	for id: StringName in keys:
		out[id] = found[id]
	return out


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
