class_name NpcfSaveCodec
extends RefCounted
## Turns a world into a save dictionary and back (R15.3). Pure: no files, no clock reads.
## Order-sensitive maps are written as pair lists in live iteration order and restored in that order,
## so a loaded world iterates exactly like the saved one. Variant values are tagged arrays (see
## decode_value). Decoding never trusts the file: every field is type-checked before use.

const SCHEMA_VERSION: int = 1
## Plain integer fields must stay below this magnitude to survive a JSON round trip exactly.
const MAX_SAFE_INT: float = 9007199254740992.0

## First error from encoding (set by encode_value and the to_save methods). Read with last_error().
static var _encode_error: String = ""


## Reads a parsed save with a latched first error: once one read fails, every later read returns a
## default value, so callers can read a whole section and check `error` once at the end.
class Reader extends RefCounted:
	var error: String = ""
	## Event kinds and action IDs the running pack defines. Decoding rejects anything else.
	var known_kinds: Dictionary = {}
	var known_actions: Dictionary = {}

	func fail(msg: String) -> void:
		if error == "":
			error = msg

	func fail_with(res: Array) -> void:
		var msg: String = res[1]
		fail(msg)

	static func join(path: String, key: String) -> String:
		return key if path == "" else path + "." + key

	## The value under a key of a JSON object. Fails when the key is absent.
	func get_v(d: Variant, key: String, path: String) -> Variant:
		if error != "":
			return null
		if typeof(d) != TYPE_DICTIONARY:
			fail("%s: expected an object" % path)
			return null
		var dict: Dictionary = d
		if not dict.has(key):
			fail("%s: missing" % join(path, key))
			return null
		return dict[key]

	func int_v(v: Variant, path: String) -> int:
		if error != "":
			return 0
		var res: Array = NpcfSaveCodec.as_int(v, path)
		if not res[0]:
			fail_with(res)
			return 0
		var i: int = res[1]
		return i

	func int64_v(v: Variant, path: String) -> int:
		if error != "":
			return 0
		var res: Array = NpcfSaveCodec.as_int64(v, path)
		if not res[0]:
			fail_with(res)
			return 0
		var i: int = res[1]
		return i

	func float_v(v: Variant, path: String) -> float:
		if error != "":
			return 0.0
		if typeof(v) == TYPE_FLOAT:
			var f: float = v
			return f
		if typeof(v) == TYPE_INT:
			var n: int = v
			return float(n)
		fail("%s: expected a number" % path)
		return 0.0

	func bool_v(v: Variant, path: String) -> bool:
		if error != "":
			return false
		if typeof(v) != TYPE_BOOL:
			fail("%s: expected a boolean" % path)
			return false
		var b: bool = v
		return b

	func str_v(v: Variant, path: String) -> String:
		if error != "":
			return ""
		if typeof(v) != TYPE_STRING:
			fail("%s: expected a string" % path)
			return ""
		var s: String = v
		return s

	func name_v(v: Variant, path: String) -> StringName:
		return StringName(str_v(v, path))

	func arr_v(v: Variant, path: String) -> Array:
		if error != "":
			return []
		if typeof(v) != TYPE_ARRAY:
			fail("%s: expected an array" % path)
			return []
		var a: Array = v
		return a

	func names_v(v: Variant, path: String) -> Array[StringName]:
		var out: Array[StringName] = []
		for item: Variant in arr_v(v, path):
			out.append(name_v(item, path))
		return out

	## A two-element array (a pair such as [key, value]). Returns [null, null] after a failure.
	func pair_v(v: Variant, path: String) -> Array:
		var a: Array = arr_v(v, path)
		if a.size() != 2:
			fail("%s: expected a pair" % path)
			return [null, null]
		return a

	func value_v(v: Variant, path: String) -> Variant:
		if error != "":
			return null
		var res: Array = NpcfSaveCodec.decode_value(v, path)
		if not res[0]:
			fail_with(res)
			return null
		return res[1]

	func int_at(d: Variant, key: String, path: String) -> int:
		return int_v(get_v(d, key, path), join(path, key))

	func int64_at(d: Variant, key: String, path: String) -> int:
		return int64_v(get_v(d, key, path), join(path, key))

	func float_at(d: Variant, key: String, path: String) -> float:
		return float_v(get_v(d, key, path), join(path, key))

	func bool_at(d: Variant, key: String, path: String) -> bool:
		return bool_v(get_v(d, key, path), join(path, key))

	func name_at(d: Variant, key: String, path: String) -> StringName:
		return name_v(get_v(d, key, path), join(path, key))

	func arr_at(d: Variant, key: String, path: String) -> Array:
		return arr_v(get_v(d, key, path), join(path, key))

	func names_at(d: Variant, key: String, path: String) -> Array[StringName]:
		return names_v(get_v(d, key, path), join(path, key))

	func value_at(d: Variant, key: String, path: String) -> Variant:
		return value_v(get_v(d, key, path), join(path, key))


## Header checks only: schema, pack namespace, pack major version, scenario ID. "" = compatible.
static func check_compatible(data: Dictionary, pack: NpcfLoadedPack, scenario: NpcfScenarioDef) -> String:
	var schema: int = _int_or(data.get("schema_version"), -1)
	if schema != SCHEMA_VERSION:
		return "save schema %d is not supported (expected %d)" % [schema, SCHEMA_VERSION]
	var pack_info: Variant = data.get("pack")
	var saved_ns: String = ""
	var saved_version: String = ""
	if typeof(pack_info) == TYPE_DICTIONARY:
		var pd: Dictionary = pack_info
		saved_ns = str(pd.get("namespace", ""))
		saved_version = str(pd.get("version", ""))
	var running_ns: String = String(pack.pack_namespace)
	if saved_ns != running_ns:
		return "save is for pack \"%s\", running pack is \"%s\"" % [saved_ns, running_ns]
	var running_version: String = pack.manifest.pack_version
	if saved_version.get_slice(".", 0) != running_version.get_slice(".", 0):
		return "save is for pack version %s, running version %s has a different major version" % [
			saved_version, running_version]
	var saved_scenario: String = str(data.get("scenario", ""))
	var running_scenario: String = String(scenario.id)
	if saved_scenario != running_scenario:
		return "save is for scenario \"%s\", running scenario is \"%s\"" % [saved_scenario, running_scenario]
	return ""


## The saved seed, or 0 when the save has none that is valid.
static func seed_of(data: Dictionary) -> int:
	var res: Array = as_int64(data.get("seed"), "seed")
	if res[0]:
		var s: int = res[1]
		return s
	return 0


## The save text: sorted keys, full float precision, one trailing newline.
static func to_text(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", true, true) + "\n"


## The parsed save, or {} when the text is not a JSON object.
static func parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = parsed
	return out


## Why the last encode failed, or "" when it succeeded.
static func last_error() -> String:
	return _encode_error


## Writes a world as a save dictionary (layout in section 2.1 of the C5 plan). Returns {} when a value
## cannot be saved; last_error() then says why.
static func encode(world: NpcfWorld) -> Dictionary:
	_encode_error = ""
	var npcs: Array = []
	for id: StringName in world.npc_ids:
		npcs.append(_npc_out(world.npc(id)))
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"framework_version": NpcfVersion.FRAMEWORK,
		"pack": {"namespace": String(world.pack.pack_namespace), "version": world.pack.manifest.pack_version},
		"scenario": String(world.scenario.id),
		"seed": str(world.rng.world_seed),
		"tick": world.clock.tick,
		"next_event_id": str(world.events.next_id),
		"next_call_id": str(world.next_call_id),
		"rng": _rng_out(world.rng.export_streams()),
		"facts": _facts_out(world.state.export_rows()),
		"npcs": npcs,
		"relationships": _relationships_out(world.relationships.export_pairs()),
		"rumors": _named_rows(world.rumors.export_shares()),
		"directives": {"next_id": world.directives.export_next_id(), "items": _items_out(world.directives.export_items())},
		"director": {
			"values": _named_rows(world.director.export_values()),
			"active_until": _named_rows(world.director.export_active()),
			"pending": _events_out(world.director.export_pending()),
		},
		"scheduler": _due_out(world.scheduler.export_due()),
		"dialogue": {
			"next_line_id": world.dialogue.export_next_line_id(),
			"last_addressee": String(world.dialogue.export_last_addressee()),
			"last_talk_tick": world.dialogue.export_last_talk_tick(),
		},
		"pending_events": _events_out(world.events.undelivered),
		"inputs": _inputs_out(world.inputs),
	}
	if _encode_error != "":
		return {}
	return data


## Overwrites the state of a freshly built world (same pack, scenario and seed) with a saved one.
## Returns "" on success. After a failure the world is half-restored and the caller must discard it.
static func restore(world: NpcfWorld, data: Dictionary) -> String:
	var header: String = check_compatible(data, world.pack, world.scenario)
	if header != "":
		return header
	if seed_of(data) != world.rng.world_seed:
		return "save seed does not match the world seed"
	var r: Reader = Reader.new()
	r.known_kinds = world.pack.event_kinds
	r.known_actions = world.pack.actions
	world.clock.tick = r.int_at(data, "tick", "")
	world.hooks.tick = world.clock.tick
	world.next_call_id = r.int64_at(data, "next_call_id", "")
	world.events.next_id = r.int64_at(data, "next_event_id", "")
	world.events.log.clear()
	world.events.undelivered = _events_in(r, r.arr_at(data, "pending_events", ""), "pending_events")
	if r.error != "":
		return r.error
	_restore_rng(world, r, data)
	if r.error != "":
		return r.error
	_restore_facts(world, r, data)
	if r.error != "":
		return r.error
	_restore_npcs(world, r, data)
	if r.error != "":
		return r.error
	_restore_occupancy(world)
	_restore_relationships(world, r, data)
	if r.error != "":
		return r.error
	_restore_rumors(world, r, data)
	if r.error != "":
		return r.error
	_restore_directives(world, r, data)
	if r.error != "":
		return r.error
	_restore_director(world, r, data)
	if r.error != "":
		return r.error
	_restore_scheduler(world, r, data)
	if r.error != "":
		return r.error
	_restore_dialogue(world, r, data)
	if r.error != "":
		return r.error
	var inputs: Array[NpcfInput] = []
	for row: Variant in r.arr_at(data, "inputs", ""):
		inputs.append(NpcfInput.from_save(r, row, "inputs"))
	world.inputs = inputs
	return r.error


## A typed value as a tagged array: ["z"], ["b", bool], ["i", "decimal"], ["f", float], ["n", "name"],
## ["s", "text"]. Returns null and sets last_error() for any other type.
static func encode_value(v: Variant, path: String) -> Variant:
	match typeof(v):
		TYPE_NIL:
			return ["z"]
		TYPE_BOOL:
			return ["b", v]
		TYPE_INT:
			return ["i", str(v)]
		TYPE_FLOAT:
			return ["f", v]
		TYPE_STRING:
			return ["s", v]
		TYPE_STRING_NAME:
			var sn: StringName = v
			return ["n", String(sn)]
	_encode_error = "unsupported value type %s at %s" % [type_string(typeof(v)), path]
	return null


## Decodes a tagged value: [true, value], or [false, error message].
static func decode_value(v: Variant, path: String) -> Array:
	if typeof(v) != TYPE_ARRAY:
		return _fail("%s: expected a tagged value" % path)
	var a: Array = v
	if a.is_empty() or typeof(a[0]) != TYPE_STRING:
		return _fail("%s: expected a tagged value" % path)
	var tag: String = a[0]
	if tag == "z" and a.size() == 1:
		return [true, null]
	if a.size() != 2:
		return _fail("%s: bad tagged value" % path)
	var body: Variant = a[1]
	match tag:
		"b":
			if typeof(body) == TYPE_BOOL:
				return [true, body]
		"i":
			return as_int64(body, path)
		"f":
			if typeof(body) == TYPE_FLOAT:
				return [true, body]
			if typeof(body) == TYPE_INT:
				var n: int = body
				return [true, float(n)]
		"n":
			if typeof(body) == TYPE_STRING:
				var name_text: String = body
				return [true, StringName(name_text)]
		"s":
			if typeof(body) == TYPE_STRING:
				return [true, body]
	return _fail("%s: bad tagged value" % path)


## A plain integer field: a JSON number with no fraction, below MAX_SAFE_INT. [true, int] or [false, error].
static func as_int(v: Variant, path: String) -> Array:
	if typeof(v) == TYPE_INT:
		var i: int = v
		return [true, i]
	if typeof(v) != TYPE_FLOAT:
		return _fail("%s: expected an integer" % path)
	var f: float = v
	if f != floorf(f) or absf(f) >= MAX_SAFE_INT:
		return _fail("%s: expected an integer" % path)
	return [true, int(f)]


## A 64-bit integer field, saved as a decimal string. [true, int] or [false, error].
static func as_int64(v: Variant, path: String) -> Array:
	if typeof(v) != TYPE_STRING:
		return _fail("%s: expected a decimal integer string" % path)
	var s: String = v
	if not s.is_valid_int():
		return _fail("%s: expected a decimal integer string" % path)
	return [true, s.to_int()]


static func _fail(msg: String) -> Array:
	return [false, msg]


static func _int_or(v: Variant, fallback: int) -> int:
	var res: Array = as_int(v, "")
	if res[0]:
		var i: int = res[1]
		return i
	return fallback


# ---- encoding helpers -------------------------------------------------------------------------------

static func _named_rows(rows: Array) -> Array:
	var out: Array = []
	for row: Array in rows:
		var key_name: StringName = row[0]
		out.append([String(key_name), row[1]])
	return out


static func _relationships_out(rows: Array) -> Array:
	var out: Array = []
	for row: Array in rows:
		var key: String = row[0]
		var values: Array = row[1]
		var causes: Array = row[2]
		out.append([key, _named_rows(values), _named_rows(causes)])
	return out


static func _rng_out(rows: Array) -> Array:
	var out: Array = []
	for row: Array in rows:
		var key: String = row[0]
		var s_seed: int = row[1]
		var s_state: int = row[2]
		out.append([key, str(s_seed), str(s_state)])
	return out


static func _facts_out(rows: Array) -> Array:
	var out: Array = []
	for row: Array in rows:
		var subject: StringName = row[0]
		var pairs: Array = row[1]
		var fact_rows: Array = []
		for pair: Array in pairs:
			var fact_id: StringName = pair[0]
			fact_rows.append([String(fact_id), encode_value(pair[1], String(subject) + "/" + String(fact_id))])
		out.append([String(subject), fact_rows])
	return out


static func _due_out(rows: Array) -> Array:
	var out: Array = []
	for row: Array in rows:
		var npc: StringName = row[0]
		var reason: StringName = row[2]
		var rule: StringName = row[4]
		out.append([String(npc), row[1], String(reason), row[3], String(rule)])
	return out


static func _items_out(items: Array) -> Array:
	var out: Array = []
	for d: NpcfDirective in items:
		out.append(d.to_save())
	return out


static func _events_out(events: Array) -> Array:
	var out: Array = []
	for e: NpcfEvent in events:
		out.append(e.to_save())
	return out


static func _inputs_out(inputs: Array) -> Array:
	var out: Array = []
	for i: NpcfInput in inputs:
		if i.kind == NpcfInput.Kind.EMBODIED or i.kind == NpcfInput.Kind.DISEMBODIED:
			continue
		out.append(i.to_save())
	return out


static func _name_int_rows(d: Dictionary[StringName, int]) -> Array:
	var out: Array = []
	for k: StringName in d:
		out.append([String(k), d[k]])
	return out


static func _npc_out(n: NpcfNpcState) -> Dictionary:
	var needs: Array = []
	for k: StringName in n.needs:
		needs.append([String(k), n.needs[k]])
	var plan: Array = []
	for c: NpcfActionCall in n.plan:
		plan.append(c.to_save())
	var running: Variant = null
	if n.running != null:
		running = _running_out(n.running)
	var beliefs: Array = []
	for b: NpcfBelief in n.beliefs.export_live():
		beliefs.append(b.to_save())
	var records: Array = []
	for rec: NpcfMemoryRecord in n.memory.records:
		records.append(rec.to_save())
	return {
		"id": String(n.id), "needs": needs, "tags": NpcfValueCodec.names(n.tags),
		"goal": String(n.current_goal), "plan": plan, "running": running,
		"cooldowns": _name_int_rows(n.cooldowns), "unreachable_until": _name_int_rows(n.unreachable_until),
		"reaction_cooldowns": _name_int_rows(n.reaction_cooldowns), "next_periodic_tick": n.next_periodic_tick,
		"beliefs": beliefs, "memory": {"next_id": n.memory.next_id, "records": records},
		"last_addressed_tick": n.last_addressed_tick,
	}


static func _running_out(run: NpcfRunningAction) -> Dictionary:
	return {
		"call": run.call.to_save(), "started_tick": run.started_tick, "elapsed": run.elapsed,
		"finished": run.finished, "timeout": run.timeout, "path": NpcfValueCodec.names(run.path),
		"path_index": run.path_index, "edge_elapsed": run.edge_elapsed, "last_location": String(run.last_location),
	}


# ---- restore helpers --------------------------------------------------------------------------------

static func _restore_rng(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	world.rng.clear()
	for row: Variant in r.arr_at(data, "rng", ""):
		var cells: Array = r.arr_v(row, "rng")
		if cells.size() != 3:
			r.fail("rng: expected [key, seed, state]")
			return
		var key: String = r.str_v(cells[0], "rng")
		var s_seed: int = r.int64_v(cells[1], "rng")
		var s_state: int = r.int64_v(cells[2], "rng")
		world.rng.restore_stream(key, s_seed, s_state)


static func _restore_facts(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	world.state = NpcfWorldState.new(world.pack.facts)
	for row: Variant in r.arr_at(data, "facts", ""):
		var kv: Array = r.pair_v(row, "facts")
		var subject: StringName = r.name_v(kv[0], "facts")
		for f: Variant in r.arr_v(kv[1], "facts"):
			var fv: Array = r.pair_v(f, "facts")
			var fact_id: StringName = r.name_v(fv[0], "facts")
			var value: Variant = r.value_v(fv[1], "facts")
			if r.error != "":
				return
			var def: NpcfFactDef = world.state.fact_def(fact_id)
			if def == null:
				r.fail("facts: unknown fact %s" % [fact_id])
				return
			if not def.accepts(value):
				r.fail("facts: %s/%s: wrong type" % [subject, fact_id])
				return
			world.state.write(subject, fact_id, value)


static func _restore_npcs(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	var rows: Array = r.arr_at(data, "npcs", "")
	if rows.size() != world.npc_ids.size():
		r.fail("npcs: saved cast does not match the scenario")
		return
	var seen: Dictionary = {}
	for row: Variant in rows:
		var id: StringName = r.name_at(row, "id", "npcs")
		var n: NpcfNpcState = world.npc(id)
		if n == null or seen.has(id):
			r.fail("npcs: saved cast does not match the scenario")
			return
		seen[id] = true
		_restore_npc(world, r, n, row)
		if r.error != "":
			return


static func _restore_npc(world: NpcfWorld, r: Reader, n: NpcfNpcState, d: Variant) -> void:
	var path: String = "npcs." + String(n.id)
	n.needs.clear()
	for row: Variant in r.arr_at(d, "needs", path):
		var kv: Array = r.pair_v(row, path)
		var need_id: StringName = r.name_v(kv[0], path)
		var amount: int = r.int_v(kv[1], path)
		n.needs[need_id] = amount
	n.tags = r.names_at(d, "tags", path)
	n.current_goal = r.name_at(d, "goal", path)
	var plan: Array[NpcfActionCall] = []
	for row: Variant in r.arr_at(d, "plan", path):
		plan.append(NpcfActionCall.from_save(r, row, path + ".plan"))
	n.plan = plan
	var running: Variant = r.get_v(d, "running", path)
	n.running = null
	if running != null:
		n.running = _running_in(world, r, running, path + ".running")
	n.cooldowns = _name_int_map(r, r.arr_at(d, "cooldowns", path), path)
	n.unreachable_until = _name_int_map(r, r.arr_at(d, "unreachable_until", path), path)
	n.reaction_cooldowns = _name_int_map(r, r.arr_at(d, "reaction_cooldowns", path), path)
	n.next_periodic_tick = r.int_at(d, "next_periodic_tick", path)
	n.last_addressed_tick = r.int_at(d, "last_addressed_tick", path)
	n.beliefs = NpcfBeliefStore.new()
	for row: Variant in r.arr_at(d, "beliefs", path):
		n.beliefs.restore(NpcfBelief.from_save(r, row, path + ".beliefs"))
	var mem: Variant = r.get_v(d, "memory", path)
	n.memory.next_id = r.int_at(mem, "next_id", path + ".memory")
	var records: Array[NpcfMemoryRecord] = []
	for row: Variant in r.arr_at(mem, "records", path + ".memory"):
		records.append(NpcfMemoryRecord.from_save(r, row, path + ".memory"))
	n.memory.records = records


static func _running_in(world: NpcfWorld, r: Reader, v: Variant, path: String) -> NpcfRunningAction:
	var run: NpcfRunningAction = NpcfRunningAction.new()
	run.call = NpcfActionCall.from_save(r, r.get_v(v, "call", path), path + ".call")
	var def: NpcfActionDef = world.pack.actions.get(run.call.action)
	if def == null and r.error == "":
		r.fail("%s: unknown action %s" % [path, run.call.action])
	run.def = def
	run.started_tick = r.int_at(v, "started_tick", path)
	run.elapsed = r.int_at(v, "elapsed", path)
	run.finished = r.bool_at(v, "finished", path)
	run.timeout = r.int_at(v, "timeout", path)
	run.path = r.names_at(v, "path", path)
	run.path_index = r.int_at(v, "path_index", path)
	run.edge_elapsed = r.int_at(v, "edge_elapsed", path)
	run.last_location = r.name_at(v, "last_location", path)
	run.embodied = false
	return run


static func _name_int_map(r: Reader, rows: Array, path: String) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for row: Variant in rows:
		var kv: Array = r.pair_v(row, path)
		var key: StringName = r.name_v(kv[0], path)
		var value: int = r.int_v(kv[1], path)
		out[key] = value
	return out


static func _restore_occupancy(world: NpcfWorld) -> void:
	world.occupancy = NpcfOccupancy.new()
	for id: StringName in world.npc_ids:
		world.occupancy.enter(id, world.location_of(id))


static func _restore_relationships(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	var rows: Array = []
	for row: Variant in r.arr_at(data, "relationships", ""):
		var cells: Array = r.arr_v(row, "relationships")
		if cells.size() != 3:
			r.fail("relationships: expected [key, values, causes]")
			return
		var key: String = r.str_v(cells[0], "relationships")
		var values: Array = _dim_pairs(r, cells[1], "relationships")
		var causes: Array = _dim_pairs(r, cells[2], "relationships")
		rows.append([key, values, causes])
	world.relationships.restore_pairs(rows)


static func _dim_pairs(r: Reader, v: Variant, path: String) -> Array:
	var out: Array = []
	for row: Variant in r.arr_v(v, path):
		var kv: Array = r.pair_v(row, path)
		var dim: StringName = r.name_v(kv[0], path)
		var value: int = r.int_v(kv[1], path)
		out.append([dim, value])
	return out


static func _restore_rumors(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	var rows: Array = []
	for row: Variant in r.arr_at(data, "rumors", ""):
		var kv: Array = r.pair_v(row, "rumors")
		var speaker: StringName = r.name_v(kv[0], "rumors")
		var ticks: Array = []
		for t: Variant in r.arr_v(kv[1], "rumors"):
			ticks.append(r.int_v(t, "rumors"))
		rows.append([speaker, ticks])
	world.rumors.restore_shares(rows)


static func _restore_directives(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	var dv: Variant = r.get_v(data, "directives", "")
	var next_id: int = r.int_at(dv, "next_id", "directives")
	var items: Array[NpcfDirective] = []
	for row: Variant in r.arr_at(dv, "items", "directives"):
		items.append(NpcfDirective.from_save(r, row, "directives/items"))
	world.directives.restore(next_id, items)


static func _restore_director(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	var dv: Variant = r.get_v(data, "director", "")
	var values: Array = []
	for row: Variant in r.arr_at(dv, "values", "director"):
		var kv: Array = r.pair_v(row, "director/values")
		var macro: StringName = r.name_v(kv[0], "director/values")
		var amount: float = r.float_v(kv[1], "director/values")
		values.append([macro, amount])
	var active: Array = []
	for row: Variant in r.arr_at(dv, "active_until", "director"):
		var av: Array = r.pair_v(row, "director/active_until")
		var rule: StringName = r.name_v(av[0], "director/active_until")
		var expiry: int = r.int_v(av[1], "director/active_until")
		active.append([rule, expiry])
	var pending: Array[NpcfEvent] = _events_in(r, r.arr_at(dv, "pending", "director"), "director/pending")
	world.director.restore_state(world, values, active, pending)


static func _restore_scheduler(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	var rows: Array = []
	for row: Variant in r.arr_at(data, "scheduler", ""):
		var cells: Array = r.arr_v(row, "scheduler")
		if cells.size() != 5:
			r.fail("scheduler: expected [npc, due_tick, reason, bypass, rule]")
			return
		rows.append([
			r.name_v(cells[0], "scheduler"), r.int_v(cells[1], "scheduler"), r.name_v(cells[2], "scheduler"),
			r.bool_v(cells[3], "scheduler"), r.name_v(cells[4], "scheduler"),
		])
	world.scheduler.restore_due(rows)


static func _restore_dialogue(world: NpcfWorld, r: Reader, data: Dictionary) -> void:
	var dv: Variant = r.get_v(data, "dialogue", "")
	var next_line: int = r.int_at(dv, "next_line_id", "dialogue")
	var addressee: StringName = r.name_at(dv, "last_addressee", "dialogue")
	var talk_tick: int = r.int_at(dv, "last_talk_tick", "dialogue")
	world.dialogue.restore_state(next_line, addressee, talk_tick)


static func _events_in(r: Reader, rows: Array, path: String) -> Array[NpcfEvent]:
	var out: Array[NpcfEvent] = []
	for row: Variant in rows:
		out.append(NpcfEvent.from_save(r, row, path))
	return out
