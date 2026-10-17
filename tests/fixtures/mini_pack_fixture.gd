class_name MiniPackFixture
extends RefCounted
## A small, valid, fully inline pack for the loader, resolver, world and hook tests. Each test
## builds its own copy and breaks it in one place. Namespace `toy`, framework 0.2.0.


static func manifest() -> NpcfPackManifest:
	var m: NpcfPackManifest = NpcfPackManifest.new()
	m.pack_namespace = &"toy"
	m.pack_version = "1.0.0"

	var mood: NpcfFactDef = NpcfFactDef.new()
	mood.id = &"toy.mood"
	mood.scope = NpcfFactDef.Scope.ENTITY
	mood.value_type = NpcfFactDef.ValueType.BOOL
	mood.default_value = false
	mood.public = true
	m.facts = [mood]

	var energy: NpcfNeedDef = make_need(&"toy.energy", 700, -1)
	energy.thresholds = {&"toy.tired": 200}
	m.needs = [energy]

	var rest_action: NpcfActionDef = NpcfActionDef.new()
	rest_action.id = &"toy.rest"
	rest_action.duration_ticks = 60
	rest_action.per_tick_need_deltas = {&"toy.energy": 6}
	m.actions = [rest_action]

	var rest_goal: NpcfGoalDef = NpcfGoalDef.new()
	rest_goal.id = &"toy.rest"
	rest_goal.candidate_actions = [rest_action]
	m.goals = [rest_goal]

	var villager: NpcfArchetypeDef = NpcfArchetypeDef.new()
	villager.id = &"toy.villager"
	villager.needs = [energy]
	villager.goals = [rest_goal]
	villager.decision_period_ticks = 5
	m.archetypes = [villager]

	var lazy: NpcfPersonalityDef = NpcfPersonalityDef.new()
	lazy.id = &"toy.lazy"
	lazy.goal_multipliers = {&"toy.rest": 1.5}
	m.personalities = [lazy]

	var ana: NpcfCharacterDef = NpcfCharacterDef.new()
	ana.id = &"toy.ana"
	ana.display_name = "Ana"
	ana.archetype = villager
	ana.personalities = [lazy]
	m.characters = [ana]

	var home: NpcfLocationDef = make_location(&"toy.home", [&"toy.home_tag"] as Array[StringName])
	var yard: NpcfLocationDef = make_location(&"toy.yard", [] as Array[StringName])
	var edge: NpcfEdgeDef = NpcfEdgeDef.new()
	edge.from_location = home
	edge.to_location = yard
	edge.travel_ticks = 5
	var graph: NpcfLocationGraph = NpcfLocationGraph.new()
	graph.locations = [home, yard]
	graph.edges = [edge]
	m.location_graph = graph
	return m


static func make_need(id: StringName, start: int, change: int) -> NpcfNeedDef:
	var n: NpcfNeedDef = NpcfNeedDef.new()
	n.id = id
	n.min_value = 0
	n.max_value = 1000
	n.start = start
	n.change_per_tick = change
	return n


static func make_location(id: StringName, tags: Array[StringName]) -> NpcfLocationDef:
	var l: NpcfLocationDef = NpcfLocationDef.new()
	l.id = id
	l.tags = tags
	return l


## The location of the manifest's graph with this ID.
static func location(m: NpcfPackManifest, id: StringName) -> NpcfLocationDef:
	for l: NpcfLocationDef in m.location_graph.locations:
		if l.id == id:
			return l
	return null


## A character by ID from the manifest.
static func character(m: NpcfPackManifest, id: StringName) -> NpcfCharacterDef:
	for c: NpcfCharacterDef in m.characters:
		if c.id == id:
			return c
	return null


## A cast entry placing a character at a location.
static func cast_entry(c: NpcfCharacterDef, at: NpcfLocationDef) -> NpcfCastEntry:
	var e: NpcfCastEntry = NpcfCastEntry.new()
	e.character = c
	e.start_location = at
	return e


## A scenario with Ana at home. Adds `extra` cast entries.
static func scenario(m: NpcfPackManifest, extra: Array[NpcfCastEntry] = []) -> NpcfScenarioDef:
	var s: NpcfScenarioDef = NpcfScenarioDef.new()
	s.id = &"toy.basic"
	s.start_minute = 480
	s.cast = [cast_entry(character(m, &"toy.ana"), location(m, &"toy.home"))]
	for e: NpcfCastEntry in extra:
		s.cast.append(e)
	return s
