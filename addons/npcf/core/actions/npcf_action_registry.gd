class_name NpcfActionRegistry
extends RefCounted
## Decides which actions are legal for an NPC right now (R9.2).


## Legal = tier matches, cooldown expired, every precondition holds under the NPC's own view.
## Location is not part of legality. Candidate order is preserved.
func legal_for(world: NpcfWorld, view: NpcfNpcView, candidates: Array[NpcfActionDef], tier: NpcfActionDef.Tier = NpcfActionDef.Tier.RULES) -> NpcfLegalActions:
	var out: NpcfLegalActions = NpcfLegalActions.new()
	var npc: NpcfNpcState = world.npc(view.npc_id())
	var tick: int = world.clock.tick
	var empty: Dictionary[StringName, Variant] = {}
	for a: NpcfActionDef in candidates:
		if a == null or a.tier != tier:
			continue
		if npc != null and npc.cooldowns.get(a.id, 0) > tick:
			continue
		var ok: bool = true
		for c: NpcfConditionDef in a.preconditions:
			if not NpcfConditions.check(world, view, c, empty, true):
				ok = false
				break
		if ok:
			out.actions.append(a)
	return out
