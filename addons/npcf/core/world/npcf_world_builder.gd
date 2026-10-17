class_name NpcfWorldBuilder
extends RefCounted
## The only code that constructs a world and its services (design "2. Architecture"). Places every
## cast entry, applies the scenario's seeded facts quietly and initializes the decision schedule.


## Builds a headless world from a loaded pack and a scenario. `adapters` null means the headless
## adapter set (no movement, perception by location, no presentation).
static func build(pack: NpcfLoadedPack, scenario: NpcfScenarioDef, world_seed: int, adapters: NpcfAdapterSet = null) -> NpcfWorld:
	var w: NpcfWorld = NpcfWorld.new()
	w.pack = pack
	w.sim = pack.sim
	w.scenario = scenario
	w.clock = NpcfClock.new(pack.sim.minutes_per_tick, scenario.start_day, scenario.start_minute)
	w.rng = NpcfRng.new(world_seed)
	w.events = NpcfEventQueue.new(pack.event_kinds)
	w.state = NpcfWorldState.new(pack.facts)
	w.occupancy = NpcfOccupancy.new()
	w.hooks = NpcfHookRunner.new(pack.pack_namespace)
	w.adapters = adapters if adapters != null else NpcfHeadlessAdapter.adapter_set()
	w.applier = NpcfEffectApplier.new()
	w.need_system = NpcfNeedSystem.new()
	w.delivery = NpcfDelivery.new()
	w.action_registry = NpcfActionRegistry.new()
	w.executor = NpcfExecutor.new()
	w.travel = NpcfTravelResolver.new()
	w.scorer = NpcfUtilityScorer.new()
	w.directives = NpcfDirectiveBoard.new()
	w.selector = NpcfGoalSelector.new()
	w.reactions = NpcfReactionRules.new()
	w.scheduler = NpcfDecisionScheduler.new()
	w.invariants = NpcfInvariants.new()

	var setup: Array[NpcfStateChange] = []
	for entry: NpcfCastEntry in scenario.cast:
		if entry == null or entry.character == null:
			continue
		var resolved: NpcfResolvedCharacter = NpcfResolver.resolve(entry)
		if w.npcs.has(resolved.id):
			continue
		var npc: NpcfNpcState = NpcfNpcState.new()
		npc.id = resolved.id
		npc.resolved = resolved
		for def: NpcfNeedDef in resolved.needs:
			var start: int = resolved.need_start.get(def.id, def.start)
			npc.needs[def.id] = clampi(start, def.min_value, def.max_value)
		npc.tags = resolved.tags.duplicate()
		w.npcs[npc.id] = npc
		w.npc_ids.append(npc.id)
		w.occupancy.enter(npc.id, &"")
		if resolved.start_location != &"":
			setup.append(NpcfStateChange.set_fact(npc.id, NpcfFramework.AT, resolved.start_location))
	w.npc_ids.sort_custom(NpcfWorldState.name_less)

	var player: StringName = pack.sim.player_entity
	if player != &"" and scenario.player_start != null:
		setup.append(NpcfStateChange.set_fact(player, NpcfFramework.AT, scenario.player_start.id))
	for seed: NpcfFactSeed in scenario.facts:
		if seed == null or seed.fact == null:
			continue
		var subject: StringName = seed.subject
		if seed.fact.scope == NpcfFactDef.Scope.GLOBAL:
			subject = NpcfFramework.GLOBAL
		setup.append(NpcfStateChange.set_fact(subject, seed.fact.id, seed.value))
	var err: String = w.applier.apply(w, setup, -1, true)
	if err != "":
		push_error("npcf: scenario setup failed: " + err)

	for id: StringName in w.npc_ids:
		w.scheduler.init_npc(w, id)
	return w
