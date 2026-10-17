class_name NpcfPackLoader
extends RefCounted
## Validates a pack manifest and everything reachable from it, collecting every error with the
## resource file and the property path inside it before failing (R2.1-R2.4, R3.4, R4.2, R9.5).
##
## Error locations: a referenced resource saved in its own .tres file is reported at that file
## with a property path starting from its root; an embedded sub-resource is reported at the
## owning file with the full property chain (`considerations[0].curve`).

const HOOK_BASES: Dictionary[StringName, String] = {
	&"consideration": "NpcfConsiderationHook", &"condition": "NpcfConditionHook",
	&"effect": "NpcfEffectHook", &"mapper": "NpcfEventMapperHook", &"resolver": "NpcfResolverHook",
	&"planner": "NpcfPlannerHook", &"director": "NpcfDirectorHook", &"intent": "NpcfIntentHook",
	&"invariant": "NpcfInvariantHook",
}

var _errors: Array[NpcfConfigError] = []
var _pack: NpcfLoadedPack = null
var _ns: StringName = &""
var _validated: Dictionary[int, bool] = {}
var _condition_stack: Array[int] = []


## Loads and validates a pack. `pack_dir_override` sets the folder hook scripts must live in when
## the manifest is not saved to a file (inline test packs); otherwise it is the manifest's folder.
func load_pack(manifest: NpcfPackManifest, framework_version: String = NpcfVersion.FRAMEWORK,
		pack_dir_override: String = "") -> NpcfLoadResult:
	_errors = []
	_validated = {}
	var result: NpcfLoadResult = NpcfLoadResult.new()
	if manifest == null:
		_err("", "", "no pack manifest given", "pass the pack's NpcfPackManifest resource")
		result.errors = _errors
		return result
	_pack = NpcfLoadedPack.new()
	_pack.manifest = manifest
	_pack.manifest_path = manifest.resource_path
	_pack.pack_dir = pack_dir_override if pack_dir_override != "" else manifest.resource_path.get_base_dir()
	_pack.registry = NpcfIdRegistry.new()
	_ns = manifest.pack_namespace
	_pack.pack_namespace = _ns
	var mf: String = manifest.resource_path

	if not _check_header(manifest, mf, framework_version):
		result.errors = _errors
		return result
	_pack.sim = manifest.sim if manifest.sim != null else NpcfSimConfig.new()

	# Framework definitions first, so pack content can reference them.
	var at: NpcfFactDef = NpcfFramework.at_fact()
	_pack.facts[at.id] = at
	for k: NpcfEventKindDef in NpcfFramework.event_kinds():
		_pack.event_kinds[k.id] = k
	var move: NpcfActionDef = NpcfFramework.move_to_action()
	_pack.actions[move.id] = move

	# Register every ID from the manifest lists.
	_register_list(manifest.facts, &"fact", mf, "facts", _pack.facts)
	_register_list(manifest.needs, &"need", mf, "needs", _pack.needs)
	_register_list(manifest.event_kinds, &"event kind", mf, "event_kinds", _pack.event_kinds)
	_register_list(manifest.goals, &"goal", mf, "goals", _pack.goals)
	_register_list(manifest.actions, &"action", mf, "actions", _pack.actions)
	_register_list(manifest.archetypes, &"archetype", mf, "archetypes", _pack.archetypes)
	_register_list(manifest.personalities, &"personality", mf, "personalities", _pack.personalities)
	_register_list(manifest.characters, &"character", mf, "characters", _pack.characters)
	_register_list(manifest.schedules, &"schedule", mf, "schedules", _pack.schedules)
	var no_map: Dictionary[StringName, Resource] = {}
	_register_list(manifest.reactions, &"reaction", mf, "reactions", no_map)
	_register_list(manifest.invariants, &"invariant", mf, "invariants", no_map)
	if manifest.social != null:
		var sf: String = _file(mf, manifest.social)
		var sp: String = _path(mf, "", "social", manifest.social)
		_register_list(manifest.social.dims, &"relationship dimension", sf, _join(sp, "dims"), _pack.rel_dims)
		_register_list(manifest.social.tag_transitions, &"tag transition", sf, _join(sp, "tag_transitions"), no_map)
	if manifest.location_graph != null:
		var gf: String = _file(mf, manifest.location_graph)
		var gp: String = _path(mf, "", "location_graph", manifest.location_graph)
		_register_list(manifest.location_graph.locations, &"location", gf, _join(gp, "locations"), _pack.locations)
	var player: StringName = _pack.sim.player_entity
	if player != &"":
		var reason: String = NpcfIds.check_pack_id(player, _ns)
		if reason != "":
			_err(_file(mf, manifest.sim), _join(_path(mf, "", "sim", manifest.sim), "player_entity"), reason, "use an ID like %s.player" % _ns)
		elif _pack.registry.has(&"character", player):
			_err(mf, _join("sim", "player_entity"), "\"%s\" is also a character ID" % player, "the player is not an NPC; give it its own ID")

	# Validate every definition.
	for i: int in manifest.facts.size():
		_fact(manifest.facts[i], _file(mf, manifest.facts[i]), _path(mf, "", "facts[%d]" % i, manifest.facts[i]))
	for i: int in manifest.needs.size():
		_need(manifest.needs[i], _file(mf, manifest.needs[i]), _path(mf, "", "needs[%d]" % i, manifest.needs[i]))
	for i: int in manifest.event_kinds.size():
		_event_kind(manifest.event_kinds[i], _file(mf, manifest.event_kinds[i]), _path(mf, "", "event_kinds[%d]" % i, manifest.event_kinds[i]))
	for i: int in manifest.goals.size():
		_goal(manifest.goals[i], _file(mf, manifest.goals[i]), _path(mf, "", "goals[%d]" % i, manifest.goals[i]))
	for i: int in manifest.actions.size():
		_action(manifest.actions[i], _file(mf, manifest.actions[i]), _path(mf, "", "actions[%d]" % i, manifest.actions[i]))
	for i: int in manifest.archetypes.size():
		_archetype(manifest.archetypes[i], _file(mf, manifest.archetypes[i]), _path(mf, "", "archetypes[%d]" % i, manifest.archetypes[i]))
	for i: int in manifest.personalities.size():
		_personality(manifest.personalities[i], _file(mf, manifest.personalities[i]), _path(mf, "", "personalities[%d]" % i, manifest.personalities[i]))
	for i: int in manifest.characters.size():
		_character(manifest.characters[i], _file(mf, manifest.characters[i]), _path(mf, "", "characters[%d]" % i, manifest.characters[i]))
	for i: int in manifest.schedules.size():
		_schedule(manifest.schedules[i], _file(mf, manifest.schedules[i]), _path(mf, "", "schedules[%d]" % i, manifest.schedules[i]))
	if manifest.social != null:
		_social(manifest.social, _file(mf, manifest.social), _path(mf, "", "social", manifest.social))
	for i: int in manifest.reactions.size():
		_reaction(manifest.reactions[i], _file(mf, manifest.reactions[i]), _path(mf, "", "reactions[%d]" % i, manifest.reactions[i]))
	for i: int in manifest.invariants.size():
		_invariant(manifest.invariants[i], _file(mf, manifest.invariants[i]), _path(mf, "", "invariants[%d]" % i, manifest.invariants[i]))
	if manifest.location_graph != null:
		_location_graph(manifest.location_graph, _file(mf, manifest.location_graph), _path(mf, "", "location_graph", manifest.location_graph))
	_sim(_pack.sim, _file(mf, manifest.sim) if manifest.sim != null else mf, _path(mf, "", "sim", manifest.sim) if manifest.sim != null else "sim")
	_pack.social = manifest.social if manifest.social != null else NpcfSocialDef.new()
	_pack.rumor_rules = _pack.social.rumors if _pack.social.rumors != null else NpcfRumorRules.new()

	for r: NpcfReactionRuleDef in manifest.reactions:
		if r != null:
			_pack.reactions.append(r)
	for inv: NpcfInvariantDef in manifest.invariants:
		if inv != null:
			_pack.invariants.append(inv)
	_pack.location_index = NpcfLocationIndex.new(manifest.location_graph)

	result.errors = _errors
	result.ok = _errors.is_empty()
	result.pack = _pack if result.ok else null
	return result


## Validates a scenario against a loaded pack (R4.6, R10.1 reachability). Returns its errors.
func check_scenario(pack: NpcfLoadedPack, scenario: NpcfScenarioDef) -> Array[NpcfConfigError]:
	_errors = []
	_pack = pack
	_ns = pack.pack_namespace
	if scenario == null:
		_err("", "", "no scenario given", "pass an NpcfScenarioDef")
		return _errors
	var f: String = scenario.resource_path
	_id(scenario.id, f, "id")
	if scenario.start_minute < 0 or scenario.start_minute > 1439:
		_err(f, "start_minute", "%d is outside 0..1439" % scenario.start_minute, "")
	if scenario.cast.is_empty():
		_err(f, "cast", "the cast is empty", "add at least one NpcfCastEntry")
	var seen: Dictionary[StringName, int] = {}
	var starts: Array[StringName] = []
	for i: int in scenario.cast.size():
		var c: NpcfCastEntry = scenario.cast[i]
		var cf: String = _file(f, c)
		var cp: String = _path(f, "", "cast[%d]" % i, c)
		if c == null:
			_err(f, "cast[%d]" % i, "is empty", "remove the entry or assign a cast entry")
			continue
		if c.character == null:
			_err(cf, _join(cp, "character"), "no character set", "assign an NpcfCharacterDef")
			continue
		var id: StringName = c.character.id
		_require(&"character", id, cf, _join(cp, "character"))
		if seen.has(id):
			_err(cf, _join(cp, "character"), "NPC \"%s\" is already in the cast (cast[%d])" % [id, seen[id]], "each NPC may appear once")
		seen[id] = i
		if c.start_location == null:
			_err(cf, _join(cp, "start_location"), "no start location set", "assign a location from the location graph")
		else:
			_require(&"location", c.start_location.id, cf, _join(cp, "start_location"))
			starts.append(c.start_location.id)
		if c.schedule != null:
			_require(&"schedule", c.schedule.id, cf, _join(cp, "schedule"))
		_need_overrides(c.need_start, c.character.archetype, cf, _join(cp, "need_start"))
		_tags(c.tags_add, cf, _join(cp, "tags_add"))
	var player: StringName = pack.sim.player_entity
	if player != &"":
		if scenario.player_start == null:
			_err(f, "player_start", "the pack declares player %s but the scenario has no player start" % player, "assign a location")
		else:
			_require(&"location", scenario.player_start.id, f, "player_start")
			starts.append(scenario.player_start.id)
	for i: int in scenario.facts.size():
		_fact_seed(scenario.facts[i], seen, _file(f, scenario.facts[i]), _path(f, "", "facts[%d]" % i, scenario.facts[i]))
	for i: int in scenario.relationships.size():
		var rs: NpcfRelSeed = scenario.relationships[i]
		var rf: String = _file(f, rs)
		var rp: String = _path(f, "", "relationships[%d]" % i, rs)
		if rs == null or rs.from_character == null or rs.to_character == null:
			_err(rf, rp, "relationship seed needs both characters", "")
			continue
		if not seen.has(rs.from_character.id) or not seen.has(rs.to_character.id):
			_err(rf, rp, "relationship seed names a character outside the cast", "")
		for dim: StringName in rs.values:
			var vp: String = _join(rp, "values[\"%s\"]" % dim)
			if not pack.rel_dims.has(dim):
				_require(&"relationship dimension", dim, rf, vp)
				continue
			var d: NpcfRelDimDef = pack.rel_dims[dim]
			var v: int = rs.values[dim]
			if v < d.min_value or v > d.max_value:
				_err(rf, vp, "%d is outside %d..%d" % [v, d.min_value, d.max_value], "")
	if pack.location_index != null and not starts.is_empty():
		var reachable: Array[StringName] = pack.location_index.reachable_from(starts)
		for id: StringName in pack.location_index.location_ids:
			if not reachable.has(id):
				_err(pack.registry.where_defined(&"location", id), "id", "location \"%s\" is unreachable from the scenario's start locations" % id,
						"add an edge to it or remove it")
	return _errors


# --- header -----------------------------------------------------------------------------------

func _check_header(m: NpcfPackManifest, mf: String, framework_version: String) -> bool:
	var fatal: bool = false
	if not NpcfIds.is_valid_namespace(m.pack_namespace):
		_err(mf, "pack_namespace", "\"%s\" is not a valid namespace" % m.pack_namespace, "use lowercase letters, digits and _, starting with a letter")
		fatal = true
	elif m.pack_namespace == NpcfIds.FRAMEWORK_NAMESPACE:
		_err(mf, "pack_namespace", "\"npcf\" is reserved for the framework", "choose your game's own namespace")
		fatal = true
	if NpcfVersion.parse(m.pack_version).is_empty():
		_err(mf, "pack_version", "\"%s\" is not major.minor.patch" % m.pack_version, "for example 1.0.0")
	var min_ok: bool = not NpcfVersion.parse(m.framework_min).is_empty()
	var max_ok: bool = not NpcfVersion.parse(m.framework_max_exclusive).is_empty()
	if not min_ok:
		_err(mf, "framework_min", "\"%s\" is not major.minor.patch" % m.framework_min, "")
	if not max_ok:
		_err(mf, "framework_max_exclusive", "\"%s\" is not major.minor.patch" % m.framework_max_exclusive, "")
	if min_ok and max_ok:
		if NpcfVersion.compare(framework_version, m.framework_min) < 0 or NpcfVersion.compare(framework_version, m.framework_max_exclusive) >= 0:
			_err(mf, "framework_min", "pack supports framework %s up to (not including) %s, running %s"
					% [m.framework_min, m.framework_max_exclusive, framework_version], "update the pack or the framework")
			fatal = true
	return not fatal


func _register_list(list: Array, kind: StringName, file: String, prop: String, into: Dictionary) -> void:
	for i: int in list.size():
		var item: Variant = list[i]
		if item == null:
			_err(file, "%s[%d]" % [prop, i], "is empty", "remove the entry or assign a resource")
			continue
		var res: Resource = item
		var id: StringName = res.get("id")
		var rf: String = _file(file, res)
		var rp: String = _path(file, "", "%s[%d]" % [prop, i], res)
		var reason: String = NpcfIds.check_pack_id(id, _ns)
		if reason != "":
			_err(rf, _join(rp, "id"), reason, "IDs look like %s.name" % _ns)
			continue
		var dup: NpcfConfigError = _pack.registry.register(kind, id, rf)
		if dup != null:
			dup.property_path = _join(rp, "id")
			_errors.append(dup)
			continue
		into[id] = res


# --- definitions --------------------------------------------------------------------------------

func _fact(f: NpcfFactDef, file: String, path: String) -> void:
	if f == null or not _first_visit(f):
		return
	if not f.accepts(f.default_value):
		_err(file, _join(path, "default_value"), "%s does not match value type %s" % [_show(f.default_value), NpcfFactDef.type_name(f.value_type)],
				"set a %s default" % NpcfFactDef.type_name(f.value_type))
	if f.bounded:
		if f.value_type != NpcfFactDef.ValueType.INT and f.value_type != NpcfFactDef.ValueType.FLOAT:
			_err(file, _join(path, "bounded"), "only int and float facts can be bounded", "turn bounded off")
		elif f.min_value > f.max_value:
			_err(file, _join(path, "min_value"), "min_value %s is greater than max_value %s" % [f.min_value, f.max_value], "")
		elif not f.in_bounds(f.default_value):
			_err(file, _join(path, "default_value"), "%s is outside %s..%s" % [_show(f.default_value), f.min_value, f.max_value], "")


func _need(n: NpcfNeedDef, file: String, path: String) -> void:
	if n == null or not _first_visit(n):
		return
	if n.min_value >= n.max_value:
		_err(file, _join(path, "max_value"), "max_value %d must be greater than min_value %d" % [n.max_value, n.min_value], "")
		return
	if n.start < n.min_value or n.start > n.max_value:
		_err(file, _join(path, "start"), "%d is outside %d..%d" % [n.start, n.min_value, n.max_value], "")
	for k: StringName in n.thresholds:
		var v: int = n.thresholds[k]
		if String(k) == "":
			_err(file, _join(path, "thresholds"), "a threshold has an empty name", "")
		elif v <= n.min_value or v > n.max_value:
			_err(file, _join(path, "thresholds[\"%s\"]" % k), "%d is outside %d..%d" % [v, n.min_value + 1, n.max_value],
					"a threshold at the minimum can never be crossed downward")


func _event_kind(k: NpcfEventKindDef, file: String, path: String) -> void:
	if k == null or not _first_visit(k):
		return
	var names: Dictionary[StringName, NpcfFieldDef] = {}
	for i: int in k.payload_fields.size():
		var fd: NpcfFieldDef = k.payload_fields[i]
		var fp: String = _join(path, "payload_fields[%d]" % i)
		if fd == null:
			_err(file, fp, "is empty", "")
			continue
		if String(fd.name) == "":
			_err(file, _join(fp, "name"), "field name is empty", "")
		elif names.has(fd.name):
			_err(file, _join(fp, "name"), "duplicate field \"%s\"" % fd.name, "")
		if fd.type == NpcfFieldDef.FieldType.ANY:
			_err(file, _join(fp, "type"), "ANY is reserved for framework events", "choose bool, int, float or string_name")
		names[fd.name] = fd
	if k.mapper != null:
		if not k.beliefs.is_empty():
			_err(file, _join(path, "beliefs"), "an event kind uses either fact templates or a mapper hook, not both", "clear beliefs or mapper")
		_hook(k.mapper, &"mapper", file, _join(path, "mapper"))
	for i: int in k.beliefs.size():
		var t: NpcfFactTemplate = k.beliefs[i]
		var tf: String = _file(file, t)
		var tp: String = _path(file, path, "beliefs[%d]" % i, t)
		if t == null:
			_err(file, _join(path, "beliefs[%d]" % i), "is empty", "")
			continue
		if t.fact == null:
			_err(tf, _join(tp, "fact"), "no fact set", "assign an NpcfFactDef")
			continue
		_require_def(&"fact", t.fact, tf, _join(tp, "fact"))
		if t.subject_from == NpcfFactTemplate.SubjectFrom.PAYLOAD and not names.has(t.subject_field):
			_err(tf, _join(tp, "subject_field"), "payload has no field \"%s\"" % t.subject_field, "name one of the event's payload fields")
		match t.value_from:
			NpcfFactTemplate.ValueFrom.LITERAL:
				if not t.fact.accepts(t.value_literal):
					_err(tf, _join(tp, "value_literal"), "%s does not match %s's type %s" % [_show(t.value_literal), t.fact.id, NpcfFactDef.type_name(t.fact.value_type)], "")
			NpcfFactTemplate.ValueFrom.PAYLOAD:
				if not names.has(t.value_field):
					_err(tf, _join(tp, "value_field"), "payload has no field \"%s\"" % t.value_field, "")
				elif names[t.value_field].type != t.fact.value_type and not (t.fact.value_type == NpcfFactDef.ValueType.FLOAT and names[t.value_field].type == NpcfFieldDef.FieldType.INT):
					_err(tf, _join(tp, "value_field"), "field \"%s\" is not %s" % [t.value_field, NpcfFactDef.type_name(t.fact.value_type)], "")
			_:
				if t.fact.value_type != NpcfFactDef.ValueType.STRING_NAME:
					_err(tf, _join(tp, "value_from"), "an actor, target or location value needs a string_name fact", "")


func _goal(g: NpcfGoalDef, file: String, path: String) -> void:
	if g == null or not _first_visit(g):
		return
	if g.weight < 0.0 or g.weight > 10.0:
		_err(file, _join(path, "weight"), "%s is outside 0.0..10.0" % g.weight, "")
	if g.hysteresis < 0.0 or g.hysteresis > 1.0:
		_err(file, _join(path, "hysteresis"), "%s is outside 0.0..1.0" % g.hysteresis, "")
	if g.unreachable_cooldown_ticks < 0:
		_err(file, _join(path, "unreachable_cooldown_ticks"), "must not be negative", "")
	for i: int in g.considerations.size():
		var c: NpcfConsiderationDef = g.considerations[i]
		_consideration(c, _file(file, c), _path(file, path, "considerations[%d]" % i, c))
	if g.interrupt != null:
		_condition(g.interrupt, _file(file, g.interrupt), _path(file, path, "interrupt", g.interrupt), [] as Array[NpcfFieldDef])
	for i: int in g.candidate_actions.size():
		var a: NpcfActionDef = g.candidate_actions[i]
		if a == null:
			_err(file, _join(path, "candidate_actions[%d]" % i), "is empty", "")
		else:
			_require_def(&"action", a, file, _join(path, "candidate_actions[%d]" % i))
	if g.script_steps != null:
		var sf: String = _file(file, g.script_steps)
		var sp: String = _path(file, path, "script_steps", g.script_steps)
		if g.script_steps.steps.is_empty():
			_err(sf, _join(sp, "steps"), "a script needs at least one step", "")
		for i: int in g.script_steps.steps.size():
			var st: NpcfScriptStep = g.script_steps.steps[i]
			var stp: String = _join(sp, "steps[%d]" % i)
			if st == null or st.action == null:
				_err(sf, stp, "step has no action", "")
				continue
			_require_def(&"action", st.action, sf, _join(stp, "action"))
			var reason: String = NpcfFieldDef.validate(st.action.args, st.args)
			if reason != "":
				_err(sf, _join(stp, "args"), reason, "match the action's declared args")


func _consideration(c: NpcfConsiderationDef, file: String, path: String) -> void:
	if c == null:
		_err(file, path, "is empty", "")
		return
	if not _first_visit(c):
		return
	match c.input:
		NpcfConsiderationDef.InputKind.NEED:
			if c.need == null:
				_err(file, _join(path, "need"), "a NEED input needs a need", "")
			else:
				_require_def(&"need", c.need, file, _join(path, "need"))
		NpcfConsiderationDef.InputKind.FACT, NpcfConsiderationDef.InputKind.BELIEF_CONFIDENCE:
			if c.fact == null:
				_err(file, _join(path, "fact"), "a %s input needs a fact" % NpcfConsiderationDef.InputKind.keys()[c.input], "")
			else:
				_require_def(&"fact", c.fact, file, _join(path, "fact"))
				if c.subject_from == NpcfConditionDef.SubjectFrom.ARG:
					_err(file, _join(path, "subject_from"), "considerations have no action arguments", "use SELF, CURRENT_LOCATION, GLOBAL or PLAYER")
				var numeric: bool = c.fact.value_type == NpcfFactDef.ValueType.INT or c.fact.value_type == NpcfFactDef.ValueType.FLOAT
				if c.input == NpcfConsiderationDef.InputKind.FACT and numeric and c.in_max <= c.in_min:
					_err(file, _join(path, "in_max"), "in_max %s must be greater than in_min %s" % [c.in_max, c.in_min], "")
		NpcfConsiderationDef.InputKind.TRAVEL_TIME:
			_tag(c.location_tag, file, _join(path, "location_tag"))
			if c.in_max <= 0.0:
				_err(file, _join(path, "in_max"), "TRAVEL_TIME normalizes by in_max, which must be positive", "")
		NpcfConsiderationDef.InputKind.HOOK:
			if c.hook == null:
				_err(file, _join(path, "hook"), "a HOOK input needs a hook script", "")
			else:
				_hook(c.hook, &"consideration", file, _join(path, "hook"))
		NpcfConsiderationDef.InputKind.RELATIONSHIP:
			if String(c.dim) == "":
				_err(file, _join(path, "dim"), "a RELATIONSHIP input needs a dimension", "")
			else:
				_require(&"relationship dimension", c.dim, file, _join(path, "dim"))
	if c.curve == NpcfConsiderationDef.CurveKind.POWER and c.exponent <= 0.0:
		_err(file, _join(path, "exponent"), "must be positive", "")


func _condition(c: NpcfConditionDef, file: String, path: String, args: Array[NpcfFieldDef]) -> void:
	if c == null:
		_err(file, path, "is empty", "")
		return
	var key: int = c.get_instance_id()
	if _condition_stack.has(key):
		_err(file, path, "condition refers back to itself (cycle)", "break the cycle")
		return
	_condition_stack.append(key)
	if c.subject_from == NpcfConditionDef.SubjectFrom.ARG and c.op_kind in [NpcfConditionDef.OpKind.FACT, NpcfConditionDef.OpKind.TAG, NpcfConditionDef.OpKind.AT_LOCATION]:
		var found: bool = false
		for a: NpcfFieldDef in args:
			if a.name == c.arg:
				found = true
		if not found:
			_err(file, _join(path, "arg"), "no action argument \"%s\"" % c.arg, "name one of the action's args")
	match c.op_kind:
		NpcfConditionDef.OpKind.FACT:
			if c.fact == null:
				_err(file, _join(path, "fact"), "a FACT condition needs a fact", "")
			else:
				_require_def(&"fact", c.fact, file, _join(path, "fact"))
				_scope_matches(c.fact, c.subject_from, file, _join(path, "subject_from"))
				if c.compare != NpcfConditionDef.Compare.EXISTS:
					if not c.fact.accepts(c.value):
						_err(file, _join(path, "value"), "%s does not match %s's type %s" % [_show(c.value), c.fact.id, NpcfFactDef.type_name(c.fact.value_type)], "")
					var ordered: bool = c.compare in [NpcfConditionDef.Compare.LT, NpcfConditionDef.Compare.LE, NpcfConditionDef.Compare.GT, NpcfConditionDef.Compare.GE]
					if ordered and not (c.fact.value_type == NpcfFactDef.ValueType.INT or c.fact.value_type == NpcfFactDef.ValueType.FLOAT):
						_err(file, _join(path, "compare"), "ordering comparisons need an int or float fact", "use EQ or NE")
		NpcfConditionDef.OpKind.NEED:
			if c.need == null:
				_err(file, _join(path, "need"), "a NEED condition needs a need", "")
			else:
				_require_def(&"need", c.need, file, _join(path, "need"))
			if typeof(c.value) != TYPE_INT:
				_err(file, _join(path, "value"), "%s is not an int" % _show(c.value), "")
		NpcfConditionDef.OpKind.TAG:
			_tag(c.tag, file, _join(path, "tag"))
		NpcfConditionDef.OpKind.AT_LOCATION:
			if (c.location == null) == (String(c.location_tag) == ""):
				_err(file, _join(path, "location"), "set exactly one of location and location_tag", "")
			elif c.location != null:
				_require_def(&"location", c.location, file, _join(path, "location"))
			else:
				_tag(c.location_tag, file, _join(path, "location_tag"))
		NpcfConditionDef.OpKind.ALL, NpcfConditionDef.OpKind.ANY:
			if c.children.is_empty():
				_err(file, _join(path, "children"), "ALL and ANY need at least one child", "")
		NpcfConditionDef.OpKind.NOT:
			if c.children.size() != 1:
				_err(file, _join(path, "children"), "NOT needs exactly one child", "")
		NpcfConditionDef.OpKind.HOOK:
			if c.hook == null:
				_err(file, _join(path, "hook"), "a HOOK condition needs a hook script", "")
			else:
				_hook(c.hook, &"condition", file, _join(path, "hook"))
	if c.op_kind in [NpcfConditionDef.OpKind.ALL, NpcfConditionDef.OpKind.ANY, NpcfConditionDef.OpKind.NOT]:
		for i: int in c.children.size():
			var ch: NpcfConditionDef = c.children[i]
			_condition(ch, _file(file, ch), _path(file, path, "children[%d]" % i, ch), args)
	_condition_stack.pop_back()


func _effect(e: NpcfEffectDef, file: String, path: String, action: NpcfActionDef) -> void:
	if e == null:
		_err(file, path, "is empty", "")
		return
	if (e.subject_from == NpcfConditionDef.SubjectFrom.ARG and not _has_arg(action, e.arg)):
		_err(file, _join(path, "arg"), "no action argument \"%s\"" % e.arg, "")
	match e.kind:
		NpcfEffectDef.Kind.SET_FACT, NpcfEffectDef.Kind.ADD_FACT:
			if e.fact == null:
				_err(file, _join(path, "fact"), "needs a fact", "")
				return
			_require_def(&"fact", e.fact, file, _join(path, "fact"))
			_scope_matches(e.fact, e.subject_from, file, _join(path, "subject_from"))
			if e.kind == NpcfEffectDef.Kind.SET_FACT and not e.fact.accepts(e.value):
				_err(file, _join(path, "value"), "%s does not match %s's type %s" % [_show(e.value), e.fact.id, NpcfFactDef.type_name(e.fact.value_type)], "")
			if e.kind == NpcfEffectDef.Kind.ADD_FACT and not (e.fact.value_type == NpcfFactDef.ValueType.INT or e.fact.value_type == NpcfFactDef.ValueType.FLOAT):
				_err(file, _join(path, "kind"), "ADD_FACT needs an int or float fact", "")
		NpcfEffectDef.Kind.NEED_DELTA:
			if e.need == null:
				_err(file, _join(path, "need"), "needs a need", "")
			else:
				_require_def(&"need", e.need, file, _join(path, "need"))
		NpcfEffectDef.Kind.TAG_ADD, NpcfEffectDef.Kind.TAG_REMOVE:
			_tag(e.tag, file, _join(path, "tag"))
		NpcfEffectDef.Kind.EMIT_EVENT:
			if e.event_kind == null:
				_err(file, _join(path, "event_kind"), "needs an event kind", "")
			else:
				_require_def(&"event kind", e.event_kind, file, _join(path, "event_kind"))
				for fd: NpcfFieldDef in e.event_kind.payload_fields:
					if fd != null and fd.required and not _has_arg(action, fd.name):
						_err(file, _join(path, "event_kind"), "payload field \"%s\" is required but the action has no such argument" % fd.name,
								"EMIT_EVENT fills payload fields from action arguments of the same name")
		NpcfEffectDef.Kind.HOOK:
			if e.hook == null:
				_err(file, _join(path, "hook"), "needs a hook script", "")
			else:
				_hook(e.hook, &"effect", file, _join(path, "hook"))
		NpcfEffectDef.Kind.REL_DELTA:
			if String(e.dim) == "":
				_err(file, _join(path, "dim"), "a REL_DELTA effect needs a relationship dimension", "")
			else:
				_require(&"relationship dimension", e.dim, file, _join(path, "dim"))
		NpcfEffectDef.Kind.SHARE_BELIEFS:
			pass  # the listeners come from the speaker's location; nothing to check


func _action(a: NpcfActionDef, file: String, path: String) -> void:
	if a == null or not _first_visit(a):
		return
	if a.cost <= 0.0:
		_err(file, _join(path, "cost"), "%s must be greater than 0" % a.cost, "")
	if a.duration_ticks < 1:
		_err(file, _join(path, "duration_ticks"), "must be at least 1", "")
	if a.cooldown_ticks < 0:
		_err(file, _join(path, "cooldown_ticks"), "must not be negative", "")
	if a.timeout_ticks < -1 or (a.timeout_ticks >= 0 and a.timeout_ticks < a.duration_ticks):
		_err(file, _join(path, "timeout_ticks"), "must be -1 or at least duration_ticks", "")
	if a.required_location != null and String(a.required_location_tag) != "":
		_err(file, _join(path, "required_location_tag"), "set at most one of required_location and required_location_tag", "")
	if a.required_location != null:
		_require_def(&"location", a.required_location, file, _join(path, "required_location"))
	if String(a.required_location_tag) != "":
		_tag(a.required_location_tag, file, _join(path, "required_location_tag"))
	var arg_names: Dictionary[StringName, bool] = {}
	for i: int in a.args.size():
		var fd: NpcfFieldDef = a.args[i]
		if fd == null or String(fd.name) == "":
			_err(file, _join(path, "args[%d]" % i), "argument needs a name", "")
			continue
		if arg_names.has(fd.name):
			_err(file, _join(path, "args[%d].name" % i), "duplicate argument \"%s\"" % fd.name, "")
		if fd.type == NpcfFieldDef.FieldType.ANY:
			_err(file, _join(path, "args[%d].type" % i), "ANY is reserved for the framework", "")
		arg_names[fd.name] = true
	for i: int in a.preconditions.size():
		var c: NpcfConditionDef = a.preconditions[i]
		_condition(c, _file(file, c), _path(file, path, "preconditions[%d]" % i, c), a.args)
	for list_name: String in ["start_effects", "end_effects", "cleanup_effects"]:
		var list: Array[NpcfEffectDef] = a.get(list_name)
		for i: int in list.size():
			var e: NpcfEffectDef = list[i]
			_effect(e, _file(file, e), _path(file, path, "%s[%d]" % [list_name, i], e), a)
			if a.tier == NpcfActionDef.Tier.DIALOGUE and e != null and e.kind != NpcfEffectDef.Kind.EMIT_EVENT:
				_err(file, _join(path, "%s[%d].kind" % [list_name, i]), "dialogue-tier actions are presentation only and may not write state",
						"move the effect to a rules-tier action, or use EMIT_EVENT")
	if a.tier == NpcfActionDef.Tier.DIALOGUE and not a.per_tick_need_deltas.is_empty():
		_err(file, _join(path, "per_tick_need_deltas"), "dialogue-tier actions may not change needs", "")
	for need_id: StringName in a.per_tick_need_deltas:
		_require(&"need", need_id, file, _join(path, "per_tick_need_deltas[\"%s\"]" % need_id))
	for i: int in a.considerations.size():
		var c: NpcfConsiderationDef = a.considerations[i]
		_consideration(c, _file(file, c), _path(file, path, "considerations[%d]" % i, c))
	if a.resolver != null:
		_hook(a.resolver, &"resolver", file, _join(path, "resolver"))


func _archetype(a: NpcfArchetypeDef, file: String, path: String) -> void:
	if a == null or not _first_visit(a):
		return
	_tags(a.tags, file, _join(path, "tags"))
	for i: int in a.needs.size():
		if a.needs[i] == null:
			_err(file, _join(path, "needs[%d]" % i), "is empty", "")
		else:
			_require_def(&"need", a.needs[i], file, _join(path, "needs[%d]" % i))
	if a.goals.is_empty():
		_err(file, _join(path, "goals"), "an archetype needs at least one goal", "")
	for i: int in a.goals.size():
		if a.goals[i] == null:
			_err(file, _join(path, "goals[%d]" % i), "is empty", "")
		else:
			_require_def(&"goal", a.goals[i], file, _join(path, "goals[%d]" % i))
	_planner(a.planner, file, _join(path, "planner"))
	if a.schedule != null:
		_require_def(&"schedule", a.schedule, file, _join(path, "schedule"))
	if a.decision_period_ticks < 1:
		_err(file, _join(path, "decision_period_ticks"), "must be at least 1", "")
	for k: StringName in a.rel_defaults:
		var kp: String = _join(path, "rel_defaults[\"%s\"]" % k)
		if not _pack.rel_dims.has(k):
			_require(&"relationship dimension", k, file, kp)
			continue
		var d: NpcfRelDimDef = _pack.rel_dims[k]
		var v: int = a.rel_defaults[k]
		if v < d.min_value or v > d.max_value:
			_err(file, kp, "%d is outside %d..%d" % [v, d.min_value, d.max_value], "")


func _personality(p: NpcfPersonalityDef, file: String, path: String) -> void:
	if p == null or not _first_visit(p):
		return
	_multipliers(p.goal_multipliers, &"goal", file, _join(path, "goal_multipliers"))
	_multipliers(p.action_multipliers, &"action", file, _join(path, "action_multipliers"))
	_tags(p.tags_add, file, _join(path, "tags_add"))
	if p.voice.length() > 300:
		_err(file, _join(path, "voice"), "is %d characters, longer than 300" % p.voice.length(), "shorten the persona text")


func _character(c: NpcfCharacterDef, file: String, path: String) -> void:
	if c == null or not _first_visit(c):
		return
	if c.archetype == null:
		_err(file, _join(path, "archetype"), "no archetype set", "assign an NpcfArchetypeDef")
	else:
		_require_def(&"archetype", c.archetype, file, _join(path, "archetype"))
	for i: int in c.personalities.size():
		if c.personalities[i] == null:
			_err(file, _join(path, "personalities[%d]" % i), "is empty", "")
		else:
			_require_def(&"personality", c.personalities[i], file, _join(path, "personalities[%d]" % i))
	if c.schedule != null:
		_require_def(&"schedule", c.schedule, file, _join(path, "schedule"))
	_planner(c.planner, file, _join(path, "planner"))
	_need_overrides(c.need_start, c.archetype, file, _join(path, "need_start"))
	_multipliers(c.goal_multipliers, &"goal", file, _join(path, "goal_multipliers"))
	_tags(c.tags_add, file, _join(path, "tags_add"))
	for i: int in c.extra_goals.size():
		if c.extra_goals[i] == null:
			_err(file, _join(path, "extra_goals[%d]" % i), "is empty", "")
		else:
			_require_def(&"goal", c.extra_goals[i], file, _join(path, "extra_goals[%d]" % i))
	if c.voice.length() > 300:
		_err(file, _join(path, "voice"), "is %d characters, longer than 300" % c.voice.length(), "")


func _schedule(s: NpcfScheduleDef, file: String, path: String) -> void:
	if s == null or not _first_visit(s):
		return
	for i: int in s.entries.size():
		var e: NpcfScheduleEntry = s.entries[i]
		var ef: String = _file(file, e)
		var ep: String = _path(file, path, "entries[%d]" % i, e)
		if e == null:
			_err(file, _join(path, "entries[%d]" % i), "is empty", "")
			continue
		if e.goal == null:
			_err(ef, _join(ep, "goal"), "no goal set", "")
		else:
			_require_def(&"goal", e.goal, ef, _join(ep, "goal"))
		if (e.location == null) == (String(e.location_tag) == ""):
			_err(ef, _join(ep, "location"), "set exactly one of location and location_tag", "")
		elif e.location != null:
			_require_def(&"location", e.location, ef, _join(ep, "location"))
		else:
			_tag(e.location_tag, ef, _join(ep, "location_tag"))
		for m: String in ["start_minute", "end_minute"]:
			var v: int = e.get(m)
			if v < 0 or v > 1440:
				_err(ef, _join(ep, m), "%d is outside 0..1440" % v, "")
		if e.start_minute == e.end_minute:
			_err(ef, _join(ep, "end_minute"), "the window is empty", "")
		for d: int in e.days:
			if d < 0 or d > 6:
				_err(ef, _join(ep, "days"), "day %d is outside 0..6" % d, "")


func _reaction(r: NpcfReactionRuleDef, file: String, path: String) -> void:
	if r == null or not _first_visit(r):
		return
	if r.event_kind == null:
		_err(file, _join(path, "event_kind"), "no event kind set", "")
	else:
		_require_def(&"event kind", r.event_kind, file, _join(path, "event_kind"))
	if r.goal == null:
		_err(file, _join(path, "goal"), "no goal set", "")
	else:
		_require_def(&"goal", r.goal, file, _join(path, "goal"))
	if r.condition != null:
		_condition(r.condition, _file(file, r.condition), _path(file, path, "condition", r.condition), [] as Array[NpcfFieldDef])
	if r.priority < 0.0 or r.priority > 1.0:
		_err(file, _join(path, "priority"), "%s is outside 0.0..1.0" % r.priority, "")
	if r.duration_ticks < 1:
		_err(file, _join(path, "duration_ticks"), "must be at least 1", "")
	if r.cooldown_ticks < 0:
		_err(file, _join(path, "cooldown_ticks"), "must not be negative", "")


func _invariant(inv: NpcfInvariantDef, file: String, path: String) -> void:
	if inv == null or not _first_visit(inv):
		return
	if inv.hook == null:
		_err(file, _join(path, "hook"), "no hook script set", "")
	else:
		_hook(inv.hook, &"invariant", file, _join(path, "hook"))


func _location_graph(g: NpcfLocationGraph, file: String, path: String) -> void:
	for i: int in g.locations.size():
		var l: NpcfLocationDef = g.locations[i]
		if l == null:
			continue
		var lf: String = _file(file, l)
		var lp: String = _path(file, path, "locations[%d]" % i, l)
		_tags(l.tags, lf, _join(lp, "tags"))
		if l.capacity < 0:
			_err(lf, _join(lp, "capacity"), "must not be negative", "0 means unlimited")
	for i: int in g.edges.size():
		var e: NpcfEdgeDef = g.edges[i]
		var ef: String = _file(file, e)
		var ep: String = _path(file, path, "edges[%d]" % i, e)
		if e == null:
			_err(file, _join(path, "edges[%d]" % i), "is empty", "")
			continue
		for end: String in ["from_location", "to_location"]:
			var loc: NpcfLocationDef = e.get(end)
			if loc == null:
				_err(ef, _join(ep, end), "no location set", "")
			elif not _pack.registry.has(&"location", loc.id):
				_err(ef, _join(ep, end), "unknown location \"%s\"" % loc.id, "add it to the graph's locations")
		if e.travel_ticks < 1:
			_err(ef, _join(ep, "travel_ticks"), "%d must be at least 1" % e.travel_ticks, "")


func _social(s: NpcfSocialDef, file: String, path: String) -> void:
	for i: int in s.dims.size():
		var d: NpcfRelDimDef = s.dims[i]
		if d == null:
			_err(file, _join(path, "dims[%d]" % i), "is empty", "")
			continue
		_rel_dim(d, _file(file, d), _path(file, path, "dims[%d]" % i, d))
	for i: int in s.delta_rules.size():
		var r: NpcfRelDeltaRule = s.delta_rules[i]
		if r == null:
			_err(file, _join(path, "delta_rules[%d]" % i), "is empty", "")
			continue
		_rel_delta(r, _file(file, r), _path(file, path, "delta_rules[%d]" % i, r))
	for i: int in s.tag_transitions.size():
		var t: NpcfTagTransitionDef = s.tag_transitions[i]
		if t == null:
			_err(file, _join(path, "tag_transitions[%d]" % i), "is empty", "")
			continue
		_tag_transition(t, _file(file, t), _path(file, path, "tag_transitions[%d]" % i, t))
	if s.rumors != null:
		_rumors(s.rumors, _file(file, s.rumors), _path(file, path, "rumors", s.rumors))


func _rel_dim(d: NpcfRelDimDef, file: String, path: String) -> void:
	if not _first_visit(d):
		return
	if d.min_value >= d.max_value:
		_err(file, _join(path, "min_value"), "min_value must be less than max_value", "")
		return
	if d.default_value < d.min_value or d.default_value > d.max_value:
		_err(file, _join(path, "default_value"), "%d is outside %d..%d" % [d.default_value, d.min_value, d.max_value], "")
	var names: Array[StringName] = []
	names.assign(d.bands.keys())
	for name: StringName in names:
		var r: Vector2i = d.bands[name]
		var bp: String = _join(path, "bands[\"%s\"]" % name)
		if String(name) == "":
			_err(file, _join(path, "bands"), "a band has an empty name", "")
		if r.x > r.y:
			_err(file, bp, "band %d..%d is empty" % [r.x, r.y], "x must not be greater than y")
		elif r.x < d.min_value or r.y > d.max_value:
			_err(file, bp, "band %d..%d is outside %d..%d" % [r.x, r.y, d.min_value, d.max_value], "")
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Vector2i = d.bands[names[i]]
			var b: Vector2i = d.bands[names[j]]
			if a.x <= b.y and b.x <= a.y:
				_err(file, _join(path, "bands"), "bands \"%s\" and \"%s\" overlap" % [names[i], names[j]], "bands must not share a value")


func _rel_delta(r: NpcfRelDeltaRule, file: String, path: String) -> void:
	if r.event_kind == null:
		_err(file, _join(path, "event_kind"), "no event kind set", "")
	else:
		_require_def(&"event kind", r.event_kind, file, _join(path, "event_kind"))
	if r.dim == null:
		_err(file, _join(path, "dim"), "no relationship dimension set", "")
	else:
		_require_def(&"relationship dimension", r.dim, file, _join(path, "dim"))
	if r.to_role == NpcfRelDeltaRule.Role.WITNESS:
		_err(file, _join(path, "to_role"), "to_role must be ACTOR_0 or TARGET_0", "a relationship is held toward a participant")
	elif r.from_role == r.to_role:
		_err(file, _join(path, "from_role"), "from_role and to_role must differ", "a participant has no relationship to itself")


func _tag_transition(t: NpcfTagTransitionDef, file: String, path: String) -> void:
	if not _first_visit(t):
		return
	_tags(t.requires_tags, file, _join(path, "requires_tags"))
	_tags(t.add, file, _join(path, "add"))
	_tags(t.remove, file, _join(path, "remove"))
	if t.add.is_empty() and t.remove.is_empty():
		_err(file, path, "changes no tags", "add or remove at least one tag")
	if t.condition != null:
		_condition(t.condition, _file(file, t.condition), _path(file, path, "condition", t.condition), [] as Array[NpcfFieldDef])


func _rumors(r: NpcfRumorRules, file: String, path: String) -> void:
	if r.max_per_period < 1:
		_err(file, _join(path, "max_per_period"), "must be at least 1", "")
	if r.period_ticks < 1:
		_err(file, _join(path, "period_ticks"), "must be at least 1", "")
	if r.beliefs_per_share < 1:
		_err(file, _join(path, "beliefs_per_share"), "must be at least 1", "")


func _sim(s: NpcfSimConfig, file: String, path: String) -> void:
	for prop: String in ["minutes_per_tick", "max_ticks_per_frame", "max_decisions_per_tick", "memory_cap", "retrieval_k", "invariant_interval_ticks", "decision_records"]:
		var v: int = s.get(prop)
		if v < 1:
			_err(file, _join(path, prop), "%d must be at least 1" % v, "")
	if s.real_seconds_per_tick <= 0.0:
		_err(file, _join(path, "real_seconds_per_tick"), "must be positive", "")
	if s.belief_decay_per_day < 0:
		_err(file, _join(path, "belief_decay_per_day"), "must not be negative", "0 disables belief decay")
	if s.staleness_limit_ticks < 0:
		_err(file, _join(path, "staleness_limit_ticks"), "must not be negative", "")


func _fact_seed(fs: NpcfFactSeed, cast_ids: Dictionary[StringName, int], file: String, path: String) -> void:
	if fs == null or fs.fact == null:
		_err(file, path, "a fact seed needs a fact", "")
		return
	_require_def(&"fact", fs.fact, file, _join(path, "fact"))
	if not fs.fact.accepts(fs.value):
		_err(file, _join(path, "value"), "%s does not match %s's type %s" % [_show(fs.value), fs.fact.id, NpcfFactDef.type_name(fs.fact.value_type)], "")
	elif not fs.fact.in_bounds(fs.value):
		_err(file, _join(path, "value"), "%s is outside %s..%s" % [_show(fs.value), fs.fact.min_value, fs.fact.max_value], "")
	match fs.fact.scope:
		NpcfFactDef.Scope.GLOBAL:
			if String(fs.subject) != "":
				_err(file, _join(path, "subject"), "global facts take no subject", "clear the subject")
		NpcfFactDef.Scope.ENTITY:
			if not cast_ids.has(fs.subject) and fs.subject != _pack.sim.player_entity:
				_err(file, _join(path, "subject"), "\"%s\" is not in the cast and is not the player" % fs.subject, "")
		NpcfFactDef.Scope.LOCATION:
			_require(&"location", fs.subject, file, _join(path, "subject"))


# --- shared checks ------------------------------------------------------------------------------

func _hook(script: Script, kind: StringName, file: String, path: String) -> void:
	var base_name: String = HOOK_BASES[kind]
	var sp: String = script.resource_path
	if _pack.pack_dir != "" and not sp.begins_with(_pack.pack_dir.trim_suffix("/") + "/"):
		_err(file, path, "hook script %s is outside the pack folder %s" % [sp, _pack.pack_dir], "move the script into the pack")
		return
	if not script.can_instantiate():
		_err(file, path, "hook script %s has errors and cannot be instantiated" % sp, "open it in the editor to see the parse errors")
		return
	if not _extends(script, base_name):
		_err(file, path, "hook script %s does not extend %s" % [sp, base_name], "change its `extends` line to %s" % base_name)
		return
	for m: Dictionary in script.get_script_method_list():
		if m["name"] == "_init":
			var margs: Array = m["args"]
			var defaults: Array = m["default_args"]
			if margs.size() > defaults.size():
				_err(file, path, "hook script %s needs constructor arguments" % sp, "hooks must be instantiable with no arguments")
				return


func _extends(script: Script, base_name: String) -> bool:
	var s: Script = script
	while s != null:
		if s.get_global_name() == StringName(base_name):
			return true
		s = s.get_base_script()
	return false


func _planner(p: NpcfPlannerRef, file: String, path: String) -> void:
	if p == null or p.kind != NpcfPlannerRef.Kind.HOOK:
		return
	if p.hook == null:
		_err(file, _join(path, "hook"), "a HOOK planner needs a script", "attach a script that extends NpcfPlannerHook")
	else:
		_hook(p.hook, &"planner", file, _join(path, "hook"))


func _multipliers(d: Dictionary[StringName, float], kind: StringName, file: String, path: String) -> void:
	for k: StringName in d:
		var v: float = d[k]
		var kp: String = "%s[\"%s\"]" % [path, k]
		if v < 0.0 or v > 3.0:
			_err(file, kp, "%s is outside 0.0..3.0" % v, "lower the multiplier or split it across two personalities")
		_require(kind, k, file, kp)


func _need_overrides(d: Dictionary[StringName, int], arch: NpcfArchetypeDef, file: String, path: String) -> void:
	for k: StringName in d:
		var kp: String = "%s[\"%s\"]" % [path, k]
		var def: NpcfNeedDef = null
		if arch != null:
			for n: NpcfNeedDef in arch.needs:
				if n != null and n.id == k:
					def = n
		if def == null:
			_err(file, kp, "unknown override key: the archetype has no need \"%s\"" % k, "override only needs the archetype declares")
		elif d[k] < def.min_value or d[k] > def.max_value:
			_err(file, kp, "%d is outside %d..%d" % [d[k], def.min_value, def.max_value], "")


func _scope_matches(f: NpcfFactDef, subject_from: NpcfConditionDef.SubjectFrom, file: String, path: String) -> void:
	var ok: bool = true
	match f.scope:
		NpcfFactDef.Scope.GLOBAL:
			ok = subject_from == NpcfConditionDef.SubjectFrom.GLOBAL
		NpcfFactDef.Scope.LOCATION:
			ok = subject_from == NpcfConditionDef.SubjectFrom.CURRENT_LOCATION or subject_from == NpcfConditionDef.SubjectFrom.ARG
		NpcfFactDef.Scope.ENTITY:
			ok = subject_from in [NpcfConditionDef.SubjectFrom.SELF, NpcfConditionDef.SubjectFrom.ARG, NpcfConditionDef.SubjectFrom.PLAYER]
	if not ok:
		var scope_name: String = NpcfFactDef.Scope.keys()[f.scope]
		var from_name: String = NpcfConditionDef.SubjectFrom.keys()[subject_from]
		_err(file, path, "%s is a %s fact, which %s cannot address" % [f.id, scope_name.to_lower(), from_name], "pick a subject of the fact's scope")


func _tags(tags: Array[StringName], file: String, path: String) -> void:
	for i: int in tags.size():
		_tag(tags[i], file, "%s[%d]" % [path, i])


func _tag(tag: StringName, file: String, path: String) -> void:
	var reason: String = NpcfIds.check_pack_id(tag, _ns)
	if reason != "":
		_err(file, path, reason, "tags are IDs too, like %s.tag" % _ns)


func _id(id: StringName, file: String, path: String) -> void:
	var reason: String = NpcfIds.check_pack_id(id, _ns)
	if reason != "":
		_err(file, path, reason, "")


func _require(kind: StringName, id: StringName, file: String, path: String) -> void:
	if id == NpcfFramework.AT and kind == &"fact":
		return
	var e: NpcfConfigError = _pack.registry.require(kind, id, file, path)
	if e != null:
		_errors.append(e)


## Requires that a referenced definition is registered under `kind` and is the same resource the
## manifest lists (a stray copy with the same ID would otherwise be silently used).
func _require_def(kind: StringName, def: Resource, file: String, path: String) -> void:
	var id: StringName = def.get("id")
	if kind == &"fact" and id == NpcfFramework.AT:
		return
	if kind == &"action" and id == NpcfFramework.MOVE_TO:
		return
	if kind == &"event kind" and _pack.event_kinds.has(id) and NpcfIds.namespace_of(id) == NpcfIds.FRAMEWORK_NAMESPACE:
		return
	_require(kind, id, file, path)


func _has_arg(action: NpcfActionDef, name: StringName) -> bool:
	for fd: NpcfFieldDef in action.args:
		if fd != null and fd.name == name:
			return true
	return false


func _first_visit(r: Resource) -> bool:
	var key: int = r.get_instance_id()
	if _validated.has(key):
		return false
	_validated[key] = true
	return true


## The file a resource is reported at: its own .tres when saved separately, else the parent's.
func _file(parent_file: String, child: Resource) -> String:
	if child == null:
		return parent_file
	var p: String = child.resource_path
	if p == "":
		return parent_file
	if p.contains("::"):
		return p.get_slice("::", 0)
	return p


## The property path of `child` within the file `_file()` reports it at.
func _path(parent_file: String, parent_path: String, prop: String, child: Resource) -> String:
	if child != null and child.resource_path != "" and not child.resource_path.contains("::") and child.resource_path != parent_file:
		return ""
	return _join(parent_path, prop)


func _join(a: String, b: String) -> String:
	if a == "":
		return b
	if b == "" :
		return a
	return a + "." + b


func _show(v: Variant) -> String:
	if typeof(v) == TYPE_STRING_NAME:
		return "&\"%s\"" % v
	if v == null:
		return "null"
	return "%s (%s)" % [str(v), type_string(typeof(v))]


func _err(file: String, path: String, reason: String, hint: String) -> void:
	_errors.append(NpcfConfigError.make(file, path, reason, hint))
