extends SceneTree
## Builds the cw pack (packs/cw) in typed GDScript and saves every resource as a .tres file.
## Run from the example root, after tools/ci/sync_example.sh:
##   godot --headless --path examples/cakeworks -s res://tools/build_cw_pack.gd
## The .tres files are committed outputs. Change this script and run it again; never hand-edit them.
## Leaf resources are saved first and reloaded, so later saves link to them by path.

const ROOT: String = "res://packs/cw"
const HOOKS: String = "res://packs/cw/hooks/"

var _exit_code: int = 0


func _init() -> void:
	var needs: Dictionary[StringName, NpcfNeedDef] = _needs()
	var facts: Dictionary[StringName, NpcfFactDef] = _facts()
	var events: Dictionary[StringName, NpcfEventKindDef] = _events(facts)
	var locs: Dictionary[StringName, NpcfLocationDef] = _locations()
	var graph: NpcfLocationGraph = _graph(locs)
	var actions: Dictionary[StringName, NpcfActionDef] = _actions(locs, events, needs)
	var goals: Dictionary[StringName, NpcfGoalDef] = _goals(needs, actions)
	var schedules: Dictionary[StringName, NpcfScheduleDef] = _schedules(goals, locs)
	var archetypes: Dictionary[StringName, NpcfArchetypeDef] = _archetypes(needs, goals, schedules)
	var personalities: Dictionary[StringName, NpcfPersonalityDef] = _personalities()
	var characters: Dictionary[StringName, NpcfCharacterDef] = _characters(archetypes, personalities)
	var dims: Dictionary[StringName, NpcfRelDimDef] = _dims()
	var social: NpcfSocialDef = _social(dims, events, needs)
	var director: NpcfDirectorDef = _director(events, goals)
	var sim: NpcfSimConfig = _sim()
	var dialogue: NpcfDialogueDef = _dialogue(dims[&"cw.trust"])

	var manifest: NpcfPackManifest = NpcfPackManifest.new()
	manifest.pack_namespace = &"cw"
	manifest.pack_version = "1.0.0"
	var fact_list: Array[NpcfFactDef] = []
	fact_list.assign(facts.values())
	manifest.facts = fact_list
	var need_list: Array[NpcfNeedDef] = []
	need_list.assign(needs.values())
	manifest.needs = need_list
	var event_list: Array[NpcfEventKindDef] = []
	event_list.assign(events.values())
	manifest.event_kinds = event_list
	var goal_list: Array[NpcfGoalDef] = []
	goal_list.assign(goals.values())
	manifest.goals = goal_list
	var action_list: Array[NpcfActionDef] = []
	action_list.assign(actions.values())
	manifest.actions = action_list
	var archetype_list: Array[NpcfArchetypeDef] = []
	archetype_list.assign(archetypes.values())
	manifest.archetypes = archetype_list
	var personality_list: Array[NpcfPersonalityDef] = []
	personality_list.assign(personalities.values())
	manifest.personalities = personality_list
	var character_list: Array[NpcfCharacterDef] = []
	character_list.assign(characters.values())
	manifest.characters = character_list
	manifest.location_graph = graph
	var schedule_list: Array[NpcfScheduleDef] = []
	schedule_list.assign(schedules.values())
	manifest.schedules = schedule_list
	manifest.social = social
	manifest.director = director
	manifest.dialogue = dialogue
	manifest.sim = sim
	_save(manifest, "pack")
	_save(_starter(characters, locs, facts), "scenarios/starter")
	_save(_demo(characters, locs, facts), "scenarios/demo")
	quit(_exit_code)


## Saves to packs/cw/<rel>.tres, then returns the reloaded copy so later references keep valid paths.
func _save(res: Resource, rel: String) -> Resource:
	var path: String = "%s/%s.tres" % [ROOT, rel]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		push_error("cw builder: save %s failed: %s" % [path, error_string(err)])
		_exit_code = 1
		return res
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if loaded == null:
		push_error("cw builder: reload %s failed" % path)
		_exit_code = 1
		return res
	return loaded


func _need(id: StringName, start: int, change: int) -> NpcfNeedDef:
	var n: NpcfNeedDef = NpcfNeedDef.new()
	n.id = id
	n.start = start
	n.change_per_tick = change
	return n


func _needs() -> Dictionary[StringName, NpcfNeedDef]:
	var out: Dictionary[StringName, NpcfNeedDef] = {}
	var hunger: NpcfNeedDef = _need(&"cw.hunger", 300, 2)
	hunger.thresholds[&"cw.peckish"] = 600
	hunger.thresholds[&"cw.starving"] = 850
	out[&"cw.hunger"] = _save(hunger, "needs/hunger") as NpcfNeedDef
	var fatigue: NpcfNeedDef = _need(&"cw.fatigue", 200, 1)
	fatigue.thresholds[&"cw.tired"] = 600
	fatigue.thresholds[&"cw.exhausted"] = 850
	out[&"cw.fatigue"] = _save(fatigue, "needs/fatigue") as NpcfNeedDef
	var stress: NpcfNeedDef = _need(&"cw.stress", 250, 0)
	stress.thresholds[&"cw.strained"] = 650
	out[&"cw.stress"] = _save(stress, "needs/stress") as NpcfNeedDef
	return out


func _fact(id: StringName, scope: NpcfFactDef.Scope, vtype: NpcfFactDef.ValueType, def: Variant, shareable: bool, rel: String) -> NpcfFactDef:
	var f: NpcfFactDef = NpcfFactDef.new()
	f.id = id
	f.scope = scope
	f.value_type = vtype
	f.default_value = def
	f.shareable = shareable
	f.public = false
	return _save(f, rel) as NpcfFactDef


func _facts() -> Dictionary[StringName, NpcfFactDef]:
	var out: Dictionary[StringName, NpcfFactDef] = {}
	out[&"cw.complained"] = _fact(&"cw.complained", NpcfFactDef.Scope.ENTITY, NpcfFactDef.ValueType.BOOL, false, true, "facts/complained")
	out[&"cw.shift_done"] = _fact(&"cw.shift_done", NpcfFactDef.Scope.ENTITY, NpcfFactDef.ValueType.BOOL, false, false, "facts/shift_done")
	out[&"cw.era"] = _fact(&"cw.era", NpcfFactDef.Scope.GLOBAL, NpcfFactDef.ValueType.INT, 1, false, "facts/era")
	return out


func _belief(fact: NpcfFactDef, value: Variant) -> NpcfFactTemplate:
	var t: NpcfFactTemplate = NpcfFactTemplate.new()
	t.fact = fact
	t.subject_from = NpcfFactTemplate.SubjectFrom.ACTOR_0
	t.value_from = NpcfFactTemplate.ValueFrom.LITERAL
	t.value_literal = value
	return t


func _event(id: StringName, salience: int, visibility: NpcfEvent.Visibility, beliefs: Array[NpcfFactTemplate], rel: String) -> NpcfEventKindDef:
	var e: NpcfEventKindDef = NpcfEventKindDef.new()
	e.id = id
	e.salience = salience
	e.visibility = visibility
	e.beliefs = beliefs
	return _save(e, rel) as NpcfEventKindDef


func _events(facts: Dictionary[StringName, NpcfFactDef]) -> Dictionary[StringName, NpcfEventKindDef]:
	var out: Dictionary[StringName, NpcfEventKindDef] = {}
	var complaint_beliefs: Array[NpcfFactTemplate] = [_belief(facts[&"cw.complained"], true)]
	out[&"cw.complaint"] = _event(&"cw.complaint", 70, NpcfEvent.Visibility.LOCAL, complaint_beliefs, "events/complaint")
	var shift_beliefs: Array[NpcfFactTemplate] = [_belief(facts[&"cw.shift_done"], true)]
	out[&"cw.shift_completed"] = _event(&"cw.shift_completed", 10, NpcfEvent.Visibility.LOCAL, shift_beliefs, "events/shift_completed")
	var no_beliefs: Array[NpcfFactTemplate] = []
	out[&"cw.chatted"] = _event(&"cw.chatted", 40, NpcfEvent.Visibility.LOCAL, no_beliefs, "events/chatted")
	out[&"cw.policy_notice"] = _event(&"cw.policy_notice", 60, NpcfEvent.Visibility.PUBLIC, no_beliefs, "events/policy_notice")
	return out


func _location(id: StringName, name: String, tags: Array[StringName], anchor: StringName, rel: String) -> NpcfLocationDef:
	var l: NpcfLocationDef = NpcfLocationDef.new()
	l.id = id
	l.display_name = name
	l.tags = tags
	l.anchor_name = anchor
	return _save(l, rel) as NpcfLocationDef


func _locations() -> Dictionary[StringName, NpcfLocationDef]:
	var out: Dictionary[StringName, NpcfLocationDef] = {}
	var work_tags: Array[StringName] = [&"cw.workplace"]
	out[&"cw.production"] = _location(&"cw.production", "Production floor", work_tags, &"cw.production", "locations/production")
	var lounge_tags: Array[StringName] = [&"cw.social", &"cw.food"]
	out[&"cw.lounge"] = _location(&"cw.lounge", "Crew lounge", lounge_tags, &"cw.lounge", "locations/lounge")
	var rest_tags: Array[StringName] = [&"cw.rest"]
	out[&"cw.dormitory"] = _location(&"cw.dormitory", "Dormitory", rest_tags, &"cw.dormitory", "locations/dormitory")
	return out


func _graph(locs: Dictionary[StringName, NpcfLocationDef]) -> NpcfLocationGraph:
	var g: NpcfLocationGraph = NpcfLocationGraph.new()
	var list: Array[NpcfLocationDef] = []
	list.assign(locs.values())
	g.locations = list
	var edges: Array[NpcfEdgeDef] = []
	edges.append(_edge(locs[&"cw.production"], locs[&"cw.lounge"]))
	edges.append(_edge(locs[&"cw.lounge"], locs[&"cw.dormitory"]))
	g.edges = edges
	return _save(g, "graph") as NpcfLocationGraph


func _edge(a: NpcfLocationDef, b: NpcfLocationDef) -> NpcfEdgeDef:
	var e: NpcfEdgeDef = NpcfEdgeDef.new()
	e.from_location = a
	e.to_location = b
	e.travel_ticks = 5
	e.bidirectional = true
	return e


func _cond_need(need: NpcfNeedDef, compare: NpcfConditionDef.Compare, value: int) -> NpcfConditionDef:
	var c: NpcfConditionDef = NpcfConditionDef.new()
	c.op_kind = NpcfConditionDef.OpKind.NEED
	c.need = need
	c.compare = compare
	c.value = value
	return c


func _cond_tag(tag: StringName) -> NpcfConditionDef:
	var c: NpcfConditionDef = NpcfConditionDef.new()
	c.op_kind = NpcfConditionDef.OpKind.TAG
	c.tag = tag
	return c


func _cond_hook(script: Script) -> NpcfConditionDef:
	var c: NpcfConditionDef = NpcfConditionDef.new()
	c.op_kind = NpcfConditionDef.OpKind.HOOK
	c.hook = script
	return c


func _emit(ev: NpcfEventKindDef) -> NpcfEffectDef:
	var e: NpcfEffectDef = NpcfEffectDef.new()
	e.kind = NpcfEffectDef.Kind.EMIT_EVENT
	e.event_kind = ev
	return e


func _share() -> NpcfEffectDef:
	var e: NpcfEffectDef = NpcfEffectDef.new()
	e.kind = NpcfEffectDef.Kind.SHARE_BELIEFS
	return e


func _action(id: StringName, duration: int) -> NpcfActionDef:
	var a: NpcfActionDef = NpcfActionDef.new()
	a.id = id
	a.duration_ticks = duration
	return a


func _actions(locs: Dictionary[StringName, NpcfLocationDef], events: Dictionary[StringName, NpcfEventKindDef], needs: Dictionary[StringName, NpcfNeedDef]) -> Dictionary[StringName, NpcfActionDef]:
	var out: Dictionary[StringName, NpcfActionDef] = {}

	var work: NpcfActionDef = _action(&"cw.work_shift", 120)
	work.required_location = locs[&"cw.production"]
	work.per_tick_need_deltas[&"cw.fatigue"] = 1
	work.per_tick_need_deltas[&"cw.hunger"] = 1
	work.per_tick_need_deltas[&"cw.stress"] = 2
	work.end_effects.append(_emit(events[&"cw.shift_completed"]))
	out[work.id] = _save(work, "actions/work_shift") as NpcfActionDef

	var eat: NpcfActionDef = _action(&"cw.eat_meal", 20)
	eat.required_location_tag = &"cw.food"
	eat.per_tick_need_deltas[&"cw.hunger"] = -25
	out[eat.id] = _save(eat, "actions/eat_meal") as NpcfActionDef

	var rest: NpcfActionDef = _action(&"cw.rest", 60)
	rest.required_location_tag = &"cw.rest"
	rest.per_tick_need_deltas[&"cw.fatigue"] = -8
	out[rest.id] = _save(rest, "actions/rest") as NpcfActionDef

	var sleep: NpcfActionDef = _action(&"cw.sleep", 240)
	sleep.required_location_tag = &"cw.rest"
	sleep.per_tick_need_deltas[&"cw.fatigue"] = -4
	out[sleep.id] = _save(sleep, "actions/sleep") as NpcfActionDef

	var chat: NpcfActionDef = _action(&"cw.chat", 10)
	chat.required_location_tag = &"cw.social"
	var chat_pre: Array[NpcfConditionDef] = [_cond_hook(load(HOOKS + "cw_someone_here.gd") as Script)]
	chat.preconditions = chat_pre
	chat.per_tick_need_deltas[&"cw.stress"] = -2
	var chat_end: Array[NpcfEffectDef] = [_emit(events[&"cw.chatted"]), _share()]
	chat.end_effects = chat_end
	out[chat.id] = _save(chat, "actions/chat") as NpcfActionDef

	var complain: NpcfActionDef = _action(&"cw.complain", 5)
	complain.required_location = locs[&"cw.production"]
	var complain_pre: Array[NpcfConditionDef] = [_cond_need(needs[&"cw.stress"], NpcfConditionDef.Compare.GE, 650)]
	complain.preconditions = complain_pre
	complain.per_tick_need_deltas[&"cw.stress"] = -20
	complain.end_effects.append(_emit(events[&"cw.complaint"]))
	out[complain.id] = _save(complain, "actions/complain") as NpcfActionDef

	var wave: NpcfActionDef = _action(&"cw.wave", 1)
	wave.tier = NpcfActionDef.Tier.DIALOGUE
	wave.presentation_cue = &"cw.wave"
	out[wave.id] = _save(wave, "actions/wave") as NpcfActionDef
	return out


func _consider_need(need: NpcfNeedDef) -> NpcfConsiderationDef:
	var c: NpcfConsiderationDef = NpcfConsiderationDef.new()
	c.input = NpcfConsiderationDef.InputKind.NEED
	c.need = need
	c.curve = NpcfConsiderationDef.CurveKind.LINEAR
	return c


func _consider_schedule() -> NpcfConsiderationDef:
	var c: NpcfConsiderationDef = NpcfConsiderationDef.new()
	c.input = NpcfConsiderationDef.InputKind.SCHEDULE
	c.curve = NpcfConsiderationDef.CurveKind.STEP
	return c


func _goal(id: StringName, weight: float, considerations: Array[NpcfConsiderationDef], candidates: Array[NpcfActionDef], rel: String, cooldown: int = 30) -> NpcfGoalDef:
	var g: NpcfGoalDef = NpcfGoalDef.new()
	g.id = id
	g.weight = weight
	g.unreachable_cooldown_ticks = cooldown
	g.considerations = considerations
	g.candidate_actions = candidates
	return _save(g, rel) as NpcfGoalDef


func _goals(needs: Dictionary[StringName, NpcfNeedDef], actions: Dictionary[StringName, NpcfActionDef]) -> Dictionary[StringName, NpcfGoalDef]:
	var out: Dictionary[StringName, NpcfGoalDef] = {}
	var work_c: Array[NpcfConsiderationDef] = [_consider_schedule()]
	var work_a: Array[NpcfActionDef] = [actions[&"cw.work_shift"]]
	out[&"cw.work"] = _goal(&"cw.work", 1.0, work_c, work_a, "goals/work")

	var eat_c: Array[NpcfConsiderationDef] = [_consider_need(needs[&"cw.hunger"])]
	var eat_a: Array[NpcfActionDef] = [actions[&"cw.eat_meal"]]
	out[&"cw.eat"] = _goal(&"cw.eat", 1.0, eat_c, eat_a, "goals/eat")

	var rest_c: Array[NpcfConsiderationDef] = [_consider_need(needs[&"cw.fatigue"])]
	var rest_a: Array[NpcfActionDef] = [actions[&"cw.rest"], actions[&"cw.sleep"]]
	out[&"cw.rest"] = _goal(&"cw.rest", 1.0, rest_c, rest_a, "goals/rest")

	var social_c: Array[NpcfConsiderationDef] = [_consider_schedule()]
	var social_a: Array[NpcfActionDef] = [actions[&"cw.chat"]]
	out[&"cw.socialize"] = _goal(&"cw.socialize", 1.5, social_c, social_a, "goals/socialize", 5)

	var vent_c: Array[NpcfConsiderationDef] = [_consider_need(needs[&"cw.stress"])]
	var vent_a: Array[NpcfActionDef] = [actions[&"cw.complain"]]
	out[&"cw.vent"] = _goal(&"cw.vent", 1.5, vent_c, vent_a, "goals/vent")
	return out


func _entry(start: int, end: int, goal: NpcfGoalDef, loc: NpcfLocationDef) -> NpcfScheduleEntry:
	var e: NpcfScheduleEntry = NpcfScheduleEntry.new()
	e.start_minute = start
	e.end_minute = end
	e.goal = goal
	e.location = loc
	return e


func _schedule(id: StringName, entries: Array[NpcfScheduleEntry], rel: String) -> NpcfScheduleDef:
	var s: NpcfScheduleDef = NpcfScheduleDef.new()
	s.id = id
	s.entries = entries
	return _save(s, rel) as NpcfScheduleDef


func _schedules(goals: Dictionary[StringName, NpcfGoalDef], locs: Dictionary[StringName, NpcfLocationDef]) -> Dictionary[StringName, NpcfScheduleDef]:
	var out: Dictionary[StringName, NpcfScheduleDef] = {}
	var work: NpcfGoalDef = goals[&"cw.work"]
	var eat: NpcfGoalDef = goals[&"cw.eat"]
	var rest: NpcfGoalDef = goals[&"cw.rest"]
	var social: NpcfGoalDef = goals[&"cw.socialize"]
	var prod: NpcfLocationDef = locs[&"cw.production"]
	var lounge: NpcfLocationDef = locs[&"cw.lounge"]
	var dorm: NpcfLocationDef = locs[&"cw.dormitory"]
	var day: Array[NpcfScheduleEntry] = [
		_entry(480, 720, work, prod),
		_entry(720, 750, eat, lounge),
		_entry(750, 960, work, prod),
		_entry(960, 1080, social, lounge),
		_entry(1380, 1440, rest, dorm),
		_entry(0, 420, rest, dorm),
	]
	out[&"cw.day_crew"] = _schedule(&"cw.day_crew", day, "schedules/day_crew")
	var evening: Array[NpcfScheduleEntry] = [
		_entry(960, 1080, social, lounge),
		_entry(1080, 1200, work, prod),
		_entry(1200, 1230, eat, lounge),
		_entry(1230, 1440, work, prod),
		_entry(120, 600, rest, dorm),
	]
	out[&"cw.evening_crew"] = _schedule(&"cw.evening_crew", evening, "schedules/evening_crew")
	return out


func _archetype(id: StringName, tags: Array[StringName], needs: Array[NpcfNeedDef], goals: Array[NpcfGoalDef], schedule: NpcfScheduleDef, rel: String) -> NpcfArchetypeDef:
	var a: NpcfArchetypeDef = NpcfArchetypeDef.new()
	a.id = id
	a.tags = tags
	a.needs = needs
	a.goals = goals
	a.schedule = schedule
	a.planner = NpcfPlannerRef.new()
	a.decision_period_ticks = 5
	a.rel_defaults[&"cw.trust"] = 50
	a.rel_defaults[&"cw.liking"] = 40
	return _save(a, rel) as NpcfArchetypeDef


func _archetypes(needs: Dictionary[StringName, NpcfNeedDef], goals: Dictionary[StringName, NpcfGoalDef], schedules: Dictionary[StringName, NpcfScheduleDef]) -> Dictionary[StringName, NpcfArchetypeDef]:
	var out: Dictionary[StringName, NpcfArchetypeDef] = {}
	var need_list: Array[NpcfNeedDef] = [needs[&"cw.hunger"], needs[&"cw.fatigue"], needs[&"cw.stress"]]
	var goal_list: Array[NpcfGoalDef] = [goals[&"cw.work"], goals[&"cw.eat"], goals[&"cw.rest"], goals[&"cw.socialize"], goals[&"cw.vent"]]
	var crew: Array[StringName] = [&"cw.crew"]
	var supervisor: Array[StringName] = [&"cw.crew", &"cw.supervisor"]
	out[&"cw.line_worker"] = _archetype(&"cw.line_worker", crew, need_list, goal_list, schedules[&"cw.day_crew"], "archetypes/line_worker")
	out[&"cw.night_baker"] = _archetype(&"cw.night_baker", crew, need_list, goal_list, schedules[&"cw.evening_crew"], "archetypes/night_baker")
	out[&"cw.supervisor"] = _archetype(&"cw.supervisor", supervisor, need_list, goal_list, schedules[&"cw.day_crew"], "archetypes/supervisor")
	return out


func _personality(id: StringName, voice: String, speech: String) -> NpcfPersonalityDef:
	var p: NpcfPersonalityDef = NpcfPersonalityDef.new()
	p.id = id
	p.voice = voice
	p.speech_instruction = speech
	return _save(p, "personalities/" + str(id).get_slice(".", 1)) as NpcfPersonalityDef


func _personalities() -> Dictionary[StringName, NpcfPersonalityDef]:
	var out: Dictionary[StringName, NpcfPersonalityDef] = {}
	out[&"cw.cheerful"] = _personality(&"cw.cheerful", "Upbeat, says 'sugar' a lot, trusts the brand.",
			"A bright, friendly young adult voice, quick and smiling.")
	out[&"cw.weary"] = _personality(&"cw.weary", "Tired veteran, dry humour, notices everything.",
			"A low, slightly hoarse middle-aged voice, slow and dry.")
	out[&"cw.anxious"] = _personality(&"cw.anxious", "Nervous, eager to please, whispers bad news.",
			"A soft, quick, slightly shaky voice that drops when worried.")
	return out


func _character(id: StringName, display: String, archetype: NpcfArchetypeDef, personality: NpcfPersonalityDef, rel: String) -> NpcfCharacterDef:
	var c: NpcfCharacterDef = NpcfCharacterDef.new()
	c.id = id
	c.display_name = display
	c.archetype = archetype
	var list: Array[NpcfPersonalityDef] = [personality]
	c.personalities = list
	c.speech_voice_id = ""
	return _save(c, rel) as NpcfCharacterDef


func _characters(archetypes: Dictionary[StringName, NpcfArchetypeDef], personalities: Dictionary[StringName, NpcfPersonalityDef]) -> Dictionary[StringName, NpcfCharacterDef]:
	var out: Dictionary[StringName, NpcfCharacterDef] = {}
	var line: NpcfArchetypeDef = archetypes[&"cw.line_worker"]
	var night: NpcfArchetypeDef = archetypes[&"cw.night_baker"]
	var sup: NpcfArchetypeDef = archetypes[&"cw.supervisor"]
	out[&"cw.mira"] = _character(&"cw.mira", "Mira", line, personalities[&"cw.cheerful"], "characters/mira")
	out[&"cw.oskar"] = _character(&"cw.oskar", "Oskar", line, personalities[&"cw.weary"], "characters/oskar")
	out[&"cw.juno"] = _character(&"cw.juno", "Juno", night, personalities[&"cw.anxious"], "characters/juno")
	var tamsin: NpcfCharacterDef = _character(&"cw.tamsin", "Tamsin", sup, personalities[&"cw.weary"], "characters/tamsin")
	tamsin.goal_multipliers[&"cw.vent"] = 0.3
	out[&"cw.tamsin"] = _save(tamsin, "characters/tamsin") as NpcfCharacterDef
	out[&"cw.rafi"] = _character(&"cw.rafi", "Rafi", line, personalities[&"cw.anxious"], "characters/rafi")
	out[&"cw.bea"] = _character(&"cw.bea", "Bea", night, personalities[&"cw.cheerful"], "characters/bea")
	out[&"cw.lev"] = _character(&"cw.lev", "Lev", night, personalities[&"cw.weary"], "characters/lev")
	out[&"cw.ines"] = _character(&"cw.ines", "Ines", line, personalities[&"cw.cheerful"], "characters/ines")
	return out


func _dim(id: StringName, bands: Dictionary[StringName, Vector2i], rel: String) -> NpcfRelDimDef:
	var d: NpcfRelDimDef = NpcfRelDimDef.new()
	d.id = id
	d.min_value = -100
	d.max_value = 100
	d.default_value = 0
	d.bands = bands
	return _save(d, rel) as NpcfRelDimDef


func _dims() -> Dictionary[StringName, NpcfRelDimDef]:
	var out: Dictionary[StringName, NpcfRelDimDef] = {}
	var trust_bands: Dictionary[StringName, Vector2i] = {
		&"cw.wary": Vector2i(-100, -31),
		&"cw.neutral": Vector2i(-30, 30),
		&"cw.trusting": Vector2i(31, 100),
	}
	out[&"cw.trust"] = _dim(&"cw.trust", trust_bands, "social/trust")
	var liking_bands: Dictionary[StringName, Vector2i] = {
		&"cw.cold": Vector2i(-100, -31),
		&"cw.neutral": Vector2i(-30, 30),
		&"cw.warm": Vector2i(31, 100),
	}
	out[&"cw.liking"] = _dim(&"cw.liking", liking_bands, "social/liking")
	return out


func _rel_rule(ev: NpcfEventKindDef, from_role: NpcfRelDeltaRule.Role, to_role: NpcfRelDeltaRule.Role, dim: NpcfRelDimDef, delta: int) -> NpcfRelDeltaRule:
	var r: NpcfRelDeltaRule = NpcfRelDeltaRule.new()
	r.event_kind = ev
	r.from_role = from_role
	r.to_role = to_role
	r.dim = dim
	r.delta = delta
	return r


func _social(dims: Dictionary[StringName, NpcfRelDimDef], events: Dictionary[StringName, NpcfEventKindDef], needs: Dictionary[StringName, NpcfNeedDef]) -> NpcfSocialDef:
	var s: NpcfSocialDef = NpcfSocialDef.new()
	var dim_list: Array[NpcfRelDimDef] = [dims[&"cw.trust"], dims[&"cw.liking"]]
	s.dims = dim_list
	# Witnesses of a chat warm to the talker. The event carries no target in v1 (see the PR deviations).
	var rules: Array[NpcfRelDeltaRule] = [
		_rel_rule(events[&"cw.chatted"], NpcfRelDeltaRule.Role.WITNESS, NpcfRelDeltaRule.Role.ACTOR_0, dims[&"cw.liking"], 2),
		_rel_rule(events[&"cw.complaint"], NpcfRelDeltaRule.Role.WITNESS, NpcfRelDeltaRule.Role.ACTOR_0, dims[&"cw.trust"], -5),
	]
	s.delta_rules = rules

	var on: NpcfTagTransitionDef = NpcfTagTransitionDef.new()
	on.id = &"cw.strain_on"
	on.condition = _cond_need(needs[&"cw.stress"], NpcfConditionDef.Compare.GE, 650)
	var on_add: Array[StringName] = [&"cw.strained"]
	on.add = on_add
	var off: NpcfTagTransitionDef = NpcfTagTransitionDef.new()
	off.id = &"cw.strain_off"
	var off_req: Array[StringName] = [&"cw.strained"]
	off.requires_tags = off_req
	off.condition = _cond_need(needs[&"cw.stress"], NpcfConditionDef.Compare.LT, 400)
	var off_remove: Array[StringName] = [&"cw.strained"]
	off.remove = off_remove
	var transitions: Array[NpcfTagTransitionDef] = [on, off]
	s.tag_transitions = transitions

	var rumors: NpcfRumorRules = NpcfRumorRules.new()
	rumors.max_per_period = 2
	rumors.period_ticks = 60
	rumors.beliefs_per_share = 1
	rumors.confidence_delta = -20
	s.rumors = rumors
	return _save(s, "social/social") as NpcfSocialDef


func _macro_delta(ev: NpcfEventKindDef, amount: float) -> NpcfMacroDelta:
	var d: NpcfMacroDelta = NpcfMacroDelta.new()
	d.event_kind = ev
	d.amount = amount
	return d


func _rule(id: StringName, conditions: Array[NpcfMacroCondition], tags: Array[StringName], goal: NpcfGoalDef, priority: float, duration: int, rel: String) -> NpcfDirectorRuleDef:
	var r: NpcfDirectorRuleDef = NpcfDirectorRuleDef.new()
	r.id = id
	r.cadence_ticks = 60
	r.conditions = conditions
	var target: NpcfTagQuery = NpcfTagQuery.new()
	target.tags_any = tags
	r.target = target
	r.goal = goal
	r.priority = priority
	r.duration_ticks = duration
	return _save(r, rel) as NpcfDirectorRuleDef


func _director(events: Dictionary[StringName, NpcfEventKindDef], goals: Dictionary[StringName, NpcfGoalDef]) -> NpcfDirectorDef:
	var macro: NpcfMacroVarDef = NpcfMacroVarDef.new()
	macro.id = &"cw.reported_disorder"
	macro.min_value = 0.0
	macro.max_value = 100.0
	macro.start = 0.0
	var macro_deltas: Array[NpcfMacroDelta] = [_macro_delta(events[&"cw.complaint"], 6.0), _macro_delta(events[&"cw.shift_completed"], -1.0)]
	macro.deltas = macro_deltas
	var macro_saved: NpcfMacroVarDef = _save(macro, "director/reported_disorder") as NpcfMacroVarDef

	var cond30: NpcfMacroCondition = NpcfMacroCondition.new()
	cond30.macro = macro_saved
	cond30.compare = NpcfConditionDef.Compare.GE
	cond30.value = 30.0
	var cond60: NpcfMacroCondition = NpcfMacroCondition.new()
	cond60.macro = macro_saved
	cond60.compare = NpcfConditionDef.Compare.GE
	cond60.value = 60.0
	var crew: Array[StringName] = [&"cw.crew"]
	var c30: Array[NpcfMacroCondition] = [cond30]
	var c60: Array[NpcfMacroCondition] = [cond60]
	var rules: Array[NpcfDirectorRuleDef] = [
		_rule(&"cw.era_optimization", c30, crew, goals[&"cw.work"], 0.4, 480, "director/era_optimization"),
		_rule(&"cw.era_asset_protection", c60, crew, goals[&"cw.work"], 0.8, 480, "director/era_asset_protection"),
	]
	var d: NpcfDirectorDef = NpcfDirectorDef.new()
	var macros: Array[NpcfMacroVarDef] = [macro_saved]
	d.macros = macros
	d.rules = rules
	return _save(d, "director/director") as NpcfDirectorDef


func _sim() -> NpcfSimConfig:
	var s: NpcfSimConfig = NpcfSimConfig.new()
	s.minutes_per_tick = 1
	s.real_seconds_per_tick = 0.5
	s.player_entity = &"cw.player"
	s.memory_threshold = 30
	return _save(s, "sim") as NpcfSimConfig


func _intent(id: StringName, description: String, keywords: PackedStringArray, result: StringName, rel_deltas: Dictionary[StringName, int], hook: Script) -> NpcfIntentDef:
	var i: NpcfIntentDef = NpcfIntentDef.new()
	i.id = id
	i.description = description
	i.keywords = keywords
	var out: NpcfOutcomeDef = NpcfOutcomeDef.new()
	out.result = result
	out.rel_deltas = rel_deltas
	i.outcome = out
	i.hook = hook
	return i


func _lines(intent: NpcfIntentDef, result: StringName, band: StringName, lines: PackedStringArray) -> NpcfDialogueLineSet:
	var s: NpcfDialogueLineSet = NpcfDialogueLineSet.new()
	s.intent = intent
	s.result = result
	s.band = band
	s.lines = lines
	return s


func _question(id: StringName, description: String, options: Array[StringName], rules: Array[NpcfPresentationRule]) -> NpcfPresentationQuestionDef:
	var q: NpcfPresentationQuestionDef = NpcfPresentationQuestionDef.new()
	q.id = id
	q.description = description
	q.options = options
	q.rules = rules
	return q


func _answer(result: StringName, answer: StringName) -> NpcfPresentationRule:
	var r: NpcfPresentationRule = NpcfPresentationRule.new()
	r.result = result
	r.answer = answer
	return r


func _dialogue(band_dim: NpcfRelDimDef) -> NpcfDialogueDef:
	var d: NpcfDialogueDef = NpcfDialogueDef.new()
	var no_hook: Script = null
	var news_hook: Script = load(HOOKS + "cw_news.gd") as Script
	var greet: NpcfIntentDef = _intent(&"cw.greet", "The player greets the crew member.",
			PackedStringArray(["hi", "hello", "hey", "morning", "evening"]), &"cw.friendly",
			{&"cw.liking": 1}, no_hook)
	var ask_work: NpcfIntentDef = _intent(&"cw.ask_work", "The player asks about the shift, the quota or the line.",
			PackedStringArray(["shift", "quota", "work", "production", "line"]), &"cw.neutral", {}, no_hook)
	var ask_news: NpcfIntentDef = _intent(&"cw.ask_news", "The player asks what the crew member has heard lately.",
			PackedStringArray(["news", "heard", "rumor", "rumour", "happened", "gossip"]), &"cw.no_news", {}, news_hook)
	var complain: NpcfIntentDef = _intent(&"cw.complain_policy", "The player complains about policy, overtime or management.",
			PackedStringArray(["unfair", "ration", "overtime", "policy", "management"]), &"cw.guarded", {}, no_hook)
	var goodbye: NpcfIntentDef = _intent(&"cw.goodbye", "The player says goodbye.",
			PackedStringArray(["bye", "later", "see you"]), &"cw.neutral", {}, no_hook)
	var smalltalk: NpcfIntentDef = _intent(&"cw.smalltalk", "The player makes small talk about the day or the weather.",
			PackedStringArray(["weather", "day", "tired"]), &"cw.neutral", {}, no_hook)
	var intents: Array[NpcfIntentDef] = [greet, ask_work, ask_news, complain, goodbye, smalltalk]
	d.intents = intents
	d.fallback_intent = smalltalk
	d.confidence_threshold = 0.34

	var line_sets: Array[NpcfDialogueLineSet] = []
	line_sets.append(_lines(greet, &"cw.friendly", &"cw.wary", PackedStringArray(["Oh. Hello. Didn't expect you here.", "Hi. Good morning, I suppose."])))
	line_sets.append(_lines(greet, &"cw.friendly", &"cw.neutral", PackedStringArray(["Hello there. I'm {npc_name}.", "Hi! The quota is waiting, but hello."])))
	line_sets.append(_lines(greet, &"cw.friendly", &"cw.trusting", PackedStringArray(["Good to see you again, friend.", "Morning, sugar! It's {npc_name}."])))
	line_sets.append(_lines(ask_work, &"cw.neutral", &"cw.wary", PackedStringArray(["The line is the line. Ask someone else.", "Quota's quota. Don't ask me twice."])))
	line_sets.append(_lines(ask_work, &"cw.neutral", &"cw.neutral", PackedStringArray(["Same shift as always, at {location_name}.", "It is {time_of_day} and the line never stops."])))
	line_sets.append(_lines(ask_work, &"cw.neutral", &"cw.trusting", PackedStringArray(["Busy, but we're getting there together.", "Shifts go faster with good company."])))
	line_sets.append(_lines(ask_news, &"cw.has_news", &"cw.wary", PackedStringArray(["I heard something. I'm not repeating it.", "Word is someone complained. Keep it quiet."])))
	line_sets.append(_lines(ask_news, &"cw.has_news", &"cw.neutral", PackedStringArray(["Someone complained about the quota. Heard it near {location_name}.", "A complaint is going round. Stay quiet about it."])))
	line_sets.append(_lines(ask_news, &"cw.has_news", &"cw.trusting", PackedStringArray(["Between us? Someone spoke up about the quota.", "Quiet, I heard somebody complain about overtime."])))
	line_sets.append(_lines(ask_news, &"cw.no_news", &"cw.wary", PackedStringArray(["Nothing I'd tell you.", "Nothing new around {location_name}."])))
	line_sets.append(_lines(ask_news, &"cw.no_news", &"cw.neutral", PackedStringArray(["Nothing new around {location_name}.", "All quiet at {location_name} this {time_of_day}."])))
	line_sets.append(_lines(ask_news, &"cw.no_news", &"cw.trusting", PackedStringArray(["Nothing worth repeating, sorry.", "Nothing, friend. A calm {time_of_day}."])))
	line_sets.append(_lines(complain, &"cw.guarded", &"cw.wary", PackedStringArray(["Watch what you say about management.", "Policy is policy. I didn't hear that."])))
	line_sets.append(_lines(complain, &"cw.guarded", &"cw.neutral", PackedStringArray(["Management says the branding is cheerful. That's all I'm saying.", "Overtime again. Mm."])))
	line_sets.append(_lines(complain, &"cw.guarded", &"cw.trusting", PackedStringArray(["Between us, the overtime wears everyone down.", "Yeah. Me too."])))
	line_sets.append(_lines(goodbye, &"cw.neutral", &"cw.wary", PackedStringArray(["Bye.", "Later."])))
	line_sets.append(_lines(goodbye, &"cw.neutral", &"cw.neutral", PackedStringArray(["See you on the line.", "See you around."])))
	line_sets.append(_lines(goodbye, &"cw.neutral", &"cw.trusting", PackedStringArray(["See you, friend. Take care of yourself.", "Bye, sugar. Mind the quota."])))
	line_sets.append(_lines(smalltalk, &"cw.neutral", &"cw.wary", PackedStringArray(["Mm.", "Is that so?"])))
	line_sets.append(_lines(smalltalk, &"cw.neutral", &"cw.neutral", PackedStringArray(["Mm, is that so?", "It is {time_of_day} already."])))
	line_sets.append(_lines(smalltalk, &"cw.neutral", &"cw.trusting", PackedStringArray(["Good day for it, isn't it?", "A shift goes faster when someone talks to you."])))
	d.lines = line_sets
	d.default_lines = PackedStringArray(["...", "Mm."])
	d.band_dim = band_dim

	var emotion_opts: Array[StringName] = [&"cw.calm", &"cw.cheerful", &"cw.tired", &"cw.annoyed", &"cw.nervous"]
	var emotion_rules: Array[NpcfPresentationRule] = [
		_answer(&"cw.friendly", &"cw.cheerful"),
		_answer(&"cw.guarded", &"cw.nervous"),
		_answer(&"cw.has_news", &"cw.nervous"),
	]
	var emotion: NpcfPresentationQuestionDef = _question(&"cw.emotion", "The crew member's facial expression.", emotion_opts, emotion_rules)
	emotion.option_descriptions = {
		&"cw.calm": "Neutral and relaxed.",
		&"cw.cheerful": "Bright and pleased.",
		&"cw.tired": "Drawn and slow.",
		&"cw.annoyed": "Irritated.",
		&"cw.nervous": "Tense and watchful.",
	}
	var delivery_opts: Array[StringName] = [&"cw.normal", &"cw.whisper", &"cw.excited", &"cw.weary"]
	var delivery_rules: Array[NpcfPresentationRule] = [
		_answer(&"cw.has_news", &"cw.whisper"),
		_answer(&"cw.friendly", &"cw.excited"),
		_answer(&"cw.guarded", &"cw.weary"),
	]
	var delivery: NpcfPresentationQuestionDef = _question(&"cw.delivery", "How the line is delivered.", delivery_opts, delivery_rules)
	var presentation: Array[NpcfPresentationQuestionDef] = [emotion, delivery]
	d.presentation = presentation
	d.delivery_question = &"cw.delivery"
	d.delivery_instructions = {
		&"cw.normal": "",
		&"cw.whisper": "Whispering, close and quiet.",
		&"cw.excited": "Faster and brighter, excited.",
		&"cw.weary": "Slow, sighing, tired.",
	}
	d.default_speech_instruction = "A clear, natural adult voice."
	d.default_speech_voice_id = ""

	var lore: NpcfLoreRules = NpcfLoreRules.new()
	var banned: PackedStringArray = PackedStringArray(["internet", "phone"])
	lore.banned_terms = banned
	lore.max_line_chars = 200
	d.lore = lore

	var llm: NpcfLlmConfig = NpcfLlmConfig.new()
	llm.max_tokens = 80
	llm.temperature = 0.7
	d.llm = llm

	d.memory_texts = {
		&"npcf.conversation": "talked with {actors}",
		&"cw.chatted": "{actors} chatted at {location}",
		&"cw.complaint": "{actors} complained about the quota at {location}",
		&"cw.shift_completed": "{actors} finished a shift at {location}",
	}
	d.max_prompt_facts = 8
	d.last_talk_window_ticks = 30
	d.default_template = _template()
	return _save(d, "dialogue/dialogue") as NpcfDialogueDef


func _template() -> NpcfPromptTemplate:
	var t: NpcfPromptTemplate = NpcfPromptTemplate.new()
	t.system_text = "You are {{npc_name}}, a crew member on a corporate ship that bakes luxury cakes. Management's branding is relentlessly cheerful. {{persona}} Stay in character. Speak in one or two short sentences. Only mention facts you were given. Reply only with JSON: {\"line\": string, \"cited_facts\": [handles], \"action\": null or {\"id\": action id, \"args\": {}}}. Facts you may cite:\n{{facts}}\nActions you may take: {{actions}}."
	t.scenario_text = "{{npc_name}} is at {{location_name}} at {{time_of_day}}. {{situation}} You remember: {{memories}}."
	var v: NpcfPromptVariant = NpcfPromptVariant.new()
	v.id = &"cw.default"
	v.text = "Shifts are long and the quota never moves."
	var variants: Array[NpcfPromptVariant] = [v]
	t.variants = variants
	var macros: Array[NpcfPromptMacro] = [
		_macro(&"npc_name", NpcfPromptMacro.Source.NPC_NAME),
		_macro(&"persona", NpcfPromptMacro.Source.PERSONA),
		_macro(&"location_name", NpcfPromptMacro.Source.LOCATION_NAME),
		_macro(&"time_of_day", NpcfPromptMacro.Source.TIME_OF_DAY),
		_macro(&"memories", NpcfPromptMacro.Source.MEMORIES),
		_macro(&"facts", NpcfPromptMacro.Source.FACTS),
		_macro(&"actions", NpcfPromptMacro.Source.ACTIONS),
	]
	t.macros = macros
	return t


func _macro(name: StringName, source: NpcfPromptMacro.Source) -> NpcfPromptMacro:
	var m: NpcfPromptMacro = NpcfPromptMacro.new()
	m.name = name
	m.source = source
	return m


## The starter scenario: three NPCs for the headless acceptance suite (and the 3-day acceptance runs).
func _starter(characters: Dictionary[StringName, NpcfCharacterDef], locs: Dictionary[StringName, NpcfLocationDef], facts: Dictionary[StringName, NpcfFactDef]) -> NpcfScenarioDef:
	var s: NpcfScenarioDef = _scenario(&"cw.starter", 470)
	var cast: Array[NpcfCastEntry] = [
		_cast(characters[&"cw.mira"], locs[&"cw.production"]),
		_cast(characters[&"cw.oskar"], locs[&"cw.production"]),
		_cast(characters[&"cw.juno"], locs[&"cw.dormitory"]),
	]
	s.cast = cast
	s.facts = _seeds(facts)
	s.player_start = locs[&"cw.lounge"]
	return s


## The demo scenario: seven NPCs, day crew at production and evening crew at the dormitory.
func _demo(characters: Dictionary[StringName, NpcfCharacterDef], locs: Dictionary[StringName, NpcfLocationDef], facts: Dictionary[StringName, NpcfFactDef]) -> NpcfScenarioDef:
	var s: NpcfScenarioDef = _scenario(&"cw.demo", 470)
	var cast: Array[NpcfCastEntry] = [
		_cast(characters[&"cw.mira"], locs[&"cw.production"]),
		_cast(characters[&"cw.oskar"], locs[&"cw.production"]),
		_cast(characters[&"cw.tamsin"], locs[&"cw.production"]),
		_cast(characters[&"cw.rafi"], locs[&"cw.production"]),
		_cast(characters[&"cw.juno"], locs[&"cw.dormitory"]),
		_cast(characters[&"cw.bea"], locs[&"cw.dormitory"]),
		_cast(characters[&"cw.lev"], locs[&"cw.dormitory"]),
	]
	s.cast = cast
	s.facts = _seeds(facts)
	s.player_start = locs[&"cw.lounge"]
	return s


func _scenario(id: StringName, minute: int) -> NpcfScenarioDef:
	var s: NpcfScenarioDef = NpcfScenarioDef.new()
	s.id = id
	s.start_day = 0
	s.start_minute = minute
	return s


## Fact seeds shared by both scenarios: the ship starts in policy era 1 (the start state; eras II and III are director rules).
func _seeds(facts: Dictionary[StringName, NpcfFactDef]) -> Array[NpcfFactSeed]:
	var seed: NpcfFactSeed = NpcfFactSeed.new()
	seed.fact = facts[&"cw.era"]
	seed.value = 1
	var out: Array[NpcfFactSeed] = [seed]
	return out


func _cast(character: NpcfCharacterDef, start: NpcfLocationDef) -> NpcfCastEntry:
	var c: NpcfCastEntry = NpcfCastEntry.new()
	c.character = character
	c.start_location = start
	return c
