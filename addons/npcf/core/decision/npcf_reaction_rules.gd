class_name NpcfReactionRules
extends RefCounted
## Reactions: a delivered event can add a personal directive and make the NPC decide at once (R8.3).
## Each rule has a cooldown per NPC. Called by delivery for every recipient.


## Applies every pack reaction that matches the delivered event and the receiver's situation.
func on_delivery(world: NpcfWorld, npc: StringName, e: NpcfEvent, source: int) -> void:
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return
	var tick: int = world.clock.tick
	for rule: NpcfReactionRuleDef in world.pack.reactions:
		if rule == null or rule.event_kind == null or rule.goal == null:
			continue
		if rule.event_kind.id != e.kind:
			continue
		if rule.witnessed_only and source != NpcfBelief.Source.WITNESSED and source != NpcfBelief.Source.PARTICIPANT:
			continue
		if n.reaction_cooldowns.get(rule.id, 0) > tick:
			continue
		if rule.condition != null and not NpcfConditions.check(world, world.view(npc), rule.condition, _no_args(), false):
			continue
		var d: NpcfDirective = NpcfDirective.new()
		d.origin = rule.id
		d.target_npc = npc
		d.goal = rule.goal.id
		d.priority = rule.priority
		d.expires_tick = tick + rule.duration_ticks
		world.directives.add(d)
		world.scheduler.mark_due(world, npc, &"reaction", true, rule.id)
		n.reaction_cooldowns[rule.id] = tick + rule.cooldown_ticks


func _no_args() -> Dictionary[StringName, Variant]:
	var empty: Dictionary[StringName, Variant] = {}
	return empty
