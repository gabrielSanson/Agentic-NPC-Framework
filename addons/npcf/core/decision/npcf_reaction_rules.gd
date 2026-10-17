class_name NpcfReactionRules
extends RefCounted
## Reactions: a delivered event can add a personal directive and make the NPC decide at once (R8.3).
## Each rule has a cooldown per NPC. Called by delivery for every recipient.

## Pack reactions with a kind and a goal, grouped by event kind, in pack order. Built on first use.
var _by_kind: Dictionary[StringName, Array] = {}
var _indexed: bool = false


## Applies every pack reaction that matches the delivered event and the receiver's situation.
func on_delivery(world: NpcfWorld, npc: StringName, e: NpcfEvent, source: int) -> void:
	if not has_rules(world, e.kind):
		return
	var n: NpcfNpcState = world.npc(npc)
	if n == null:
		return
	var tick: int = world.clock.tick
	var rules: Array = _by_kind[e.kind]
	for rule: NpcfReactionRuleDef in rules:
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


## True when some pack reaction is triggered by this event kind.
func has_rules(world: NpcfWorld, kind: StringName) -> bool:
	if not _indexed:
		_index(world)
	return _by_kind.has(kind)


func _index(world: NpcfWorld) -> void:
	_indexed = true
	for rule: NpcfReactionRuleDef in world.pack.reactions:
		if rule == null or rule.event_kind == null or rule.goal == null:
			continue
		var kind: StringName = rule.event_kind.id
		if not _by_kind.has(kind):
			var fresh: Array[NpcfReactionRuleDef] = []
			_by_kind[kind] = fresh
		var list: Array = _by_kind[kind]
		list.append(rule)


func _no_args() -> Dictionary[StringName, Variant]:
	var empty: Dictionary[StringName, Variant] = {}
	return empty
