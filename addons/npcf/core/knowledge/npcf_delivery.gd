class_name NpcfDelivery
extends RefCounted
## Delivers committed events to NPCs as beliefs (R6.2-R6.4, design "5. Beliefs").
## TODO(task 9): recipients and belief writes are not implemented yet. Delivery currently drains the
## undelivered queue so the log and memory stay bounded, and delivers to nobody.


## Takes the events committed since the last delivery phase. Recipients are not computed yet.
func deliver_pending(world: NpcfWorld) -> void:
	world.events.take_undelivered()


## Recipients of an event, NPC -> NpcfBelief.Source. Empty until task 9.
func recipients(_world: NpcfWorld, _e: NpcfEvent) -> Dictionary[StringName, int]:
	return {}


## Lowers the confidence of told and broadcast beliefs of every NPC by the sim's daily decay.
func decay_beliefs(world: NpcfWorld) -> void:
	var amount: int = world.sim.belief_decay_per_day
	if amount <= 0:
		return
	for id: StringName in world.npc_ids:
		var npc: NpcfNpcState = world.npc(id)
		if npc != null:
			npc.beliefs.decay(amount)
