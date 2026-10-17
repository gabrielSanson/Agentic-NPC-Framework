class_name NpcfRelationships
extends RefCounted
## Directed relationship values (R11.1). Written only through NpcfEffectApplier (REL_DELTA changes);
## seeded by the world builder. Unset pairs read as the holder's archetype rel_defaults, else the dimension default.

const CHANGE_LOG_CAP: int = 256


## One entry per (holder, other) pair: dim -> value and dim -> cause event of the last change.
class Pair extends RefCounted:
	var values: Dictionary[StringName, int] = {}
	var causes: Dictionary[StringName, int] = {}


var _pairs: Dictionary[String, Pair] = {}
## Rule indexes for apply_event_rules, built on first use.
var _by_kind: Dictionary[StringName, Array] = {}
var _indexed: bool = false
## Most recent changes, oldest first, capped at CHANGE_LOG_CAP. For traces and tests.
var changes: Array[NpcfRelChange] = []


## The value of one dimension for a pair (archetype default or dimension default when unset).
func value(world: NpcfWorld, holder: StringName, other: StringName, dim: StringName) -> int:
	var def: NpcfRelDimDef = world.pack.rel_dims.get(dim)
	if def == null:
		return 0
	var pair: Pair = _pairs.get(_key(holder, other))
	if pair != null and pair.values.has(dim):
		return pair.values[dim]
	var n: NpcfNpcState = world.npc(holder)
	if n != null and n.resolved != null and n.resolved.rel_defaults.has(dim):
		return n.resolved.rel_defaults[dim]
	return def.default_value


## The name of the band containing the value, or &"" when no band contains it.
func band(world: NpcfWorld, holder: StringName, other: StringName, dim: StringName) -> StringName:
	var def: NpcfRelDimDef = world.pack.rel_dims.get(dim)
	if def == null:
		return &""
	var v: int = value(world, holder, other, dim)
	for band_name: StringName in def.bands:
		var range_: Vector2i = def.bands[band_name]
		if v >= range_.x and v <= range_.y:
			return band_name
	return &""


## The event ID of the last change to this value, or -1 when it was never changed.
func last_cause(holder: StringName, other: StringName, dim: StringName) -> int:
	var pair: Pair = _pairs.get(_key(holder, other))
	if pair != null and pair.causes.has(dim):
		return pair.causes[dim]
	return -1


## The value normalized to 0..1 over the dimension's bounds.
func normalized(world: NpcfWorld, holder: StringName, other: StringName, dim: StringName) -> float:
	var def: NpcfRelDimDef = world.pack.rel_dims.get(dim)
	if def == null or def.max_value <= def.min_value:
		return 0.0
	var v: int = value(world, holder, other, dim)
	return clampf(float(v - def.min_value) / float(def.max_value - def.min_value), 0.0, 1.0)


## Sets a starting value without a cause (builder only; clamped).
func seed_value(world: NpcfWorld, holder: StringName, other: StringName, dim: StringName, v: int) -> void:
	var def: NpcfRelDimDef = world.pack.rel_dims.get(dim)
	if def == null:
		return
	_pair(holder, other).values[dim] = clampi(v, def.min_value, def.max_value)


## Pair rows in live order, [[key, [[dim, value], ...], [[dim, cause], ...]], ...], for saves.
func export_pairs() -> Array:
	var out: Array = []
	for key: String in _pairs:
		var p: Pair = _pairs[key]
		out.append([key, _dim_rows(p.values), _dim_rows(p.causes)])
	return out


## Replaces every pair with saved rows (same shape as export_pairs) in saved order. Clears the change log.
func restore_pairs(rows: Array) -> void:
	_pairs.clear()
	changes.clear()
	for row: Array in rows:
		var key: String = row[0]
		var p: Pair = Pair.new()
		var values: Array = row[1]
		var causes: Array = row[2]
		for dv: Array in values:
			var dim: StringName = dv[0]
			var v: int = dv[1]
			p.values[dim] = v
		for dc: Array in causes:
			var cdim: StringName = dc[0]
			var cause: int = dc[1]
			p.causes[cdim] = cause
		_pairs[key] = p


## Values outside their dimension's bounds, as [key, dim, value] rows (for the invariant check).
func out_of_bounds(world: NpcfWorld) -> Array:
	var out: Array = []
	for key: String in _pairs:
		var p: Pair = _pairs[key]
		for dim: StringName in p.values:
			var def: NpcfRelDimDef = world.pack.rel_dims.get(dim)
			var v: int = p.values[dim]
			if def != null and (v < def.min_value or v > def.max_value):
				out.append([key, dim, v])
	return out


static func _dim_rows(d: Dictionary[StringName, int]) -> Array:
	var out: Array = []
	for dim: StringName in d:
		out.append([dim, d[dim]])
	return out


## Applier handler for REL_DELTA: holder = change.subject, other = change.other, dim = change.dim, delta = change.amount.
## Clamps, records the cause and a NpcfRelChange. Ignores holder == other, an unknown dim, or a holder that is not an NPC.
func on_change(world: NpcfWorld, change: NpcfStateChange, cause_event: int) -> String:
	var holder: StringName = change.subject
	var other: StringName = change.other
	if holder == other or world.npc(holder) == null:
		return ""
	var def: NpcfRelDimDef = world.pack.rel_dims.get(change.dim)
	if def == null:
		return ""
	var old: int = value(world, holder, other, change.dim)
	var next: int = clampi(old + change.amount, def.min_value, def.max_value)
	var pair: Pair = _pair(holder, other)
	pair.values[change.dim] = next
	pair.causes[change.dim] = cause_event
	var rec: NpcfRelChange = NpcfRelChange.new()
	rec.tick = world.clock.tick
	rec.holder = holder
	rec.other = other
	rec.dim = change.dim
	rec.old_value = old
	rec.new_value = next
	rec.cause_event = cause_event
	changes.append(rec)
	if changes.size() > CHANGE_LOG_CAP:
		changes.remove_at(0)
	return ""


## Phase 6: applies the pack's delta rules for one delivered event. Every matching rule contributes the pairs it
## names, applied together as one REL_DELTA batch.
func apply_event_rules(world: NpcfWorld, e: NpcfEvent, recipients: Dictionary[StringName, int]) -> void:
	if not _indexed:
		_index(world)
	if not _by_kind.has(e.kind):
		return
	var rules: Array = _by_kind[e.kind]
	var batch: Array[NpcfStateChange] = []
	for rule: NpcfRelDeltaRule in rules:
		var other: StringName = _party(e, rule.to_role)
		if other == &"":
			continue
		for holder: StringName in _holders(world, e, rule, recipients):
			if holder == other or world.npc(holder) == null:
				continue
			var c: NpcfStateChange = NpcfStateChange.new()
			c.kind = NpcfStateChange.Kind.REL_DELTA
			c.subject = holder
			c.other = other
			c.dim = rule.dim.id
			c.amount = rule.delta
			batch.append(c)
	if not batch.is_empty():
		world.applier.apply(world, batch, e.id)


func _index(world: NpcfWorld) -> void:
	_indexed = true
	for rule: NpcfRelDeltaRule in world.pack.social.delta_rules:
		if rule == null or rule.event_kind == null or rule.dim == null:
			continue
		var kind: StringName = rule.event_kind.id
		if not _by_kind.has(kind):
			var fresh: Array[NpcfRelDeltaRule] = []
			_by_kind[kind] = fresh
		var list: Array = _by_kind[kind]
		list.append(rule)


## The event participant in a role (ACTOR_0 or TARGET_0), or &"" when the event has none.
static func _party(e: NpcfEvent, role: NpcfRelDeltaRule.Role) -> StringName:
	if role == NpcfRelDeltaRule.Role.ACTOR_0:
		return e.actors[0] if not e.actors.is_empty() else &""
	if role == NpcfRelDeltaRule.Role.TARGET_0:
		return e.targets[0] if not e.targets.is_empty() else &""
	return &""


## The holders a rule applies to, in ID order for WITNESS.
static func _holders(world: NpcfWorld, e: NpcfEvent, rule: NpcfRelDeltaRule, recipients: Dictionary[StringName, int]) -> Array[StringName]:
	var out: Array[StringName] = []
	if rule.from_role == NpcfRelDeltaRule.Role.WITNESS:
		for id: StringName in world.npc_ids:
			var source: int = recipients.get(id, -1)
			if source == NpcfBelief.Source.WITNESSED:
				out.append(id)
		return out
	var party: StringName = _party(e, rule.from_role)
	if party != &"":
		out.append(party)
	return out


func _pair(holder: StringName, other: StringName) -> Pair:
	var key: String = _key(holder, other)
	var p: Pair = _pairs.get(key)
	if p == null:
		p = Pair.new()
		_pairs[key] = p
	return p


static func _key(holder: StringName, other: StringName) -> String:
	return "%s|%s" % [holder, other]
