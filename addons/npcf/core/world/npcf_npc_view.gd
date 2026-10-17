class_name NpcfNpcView
extends RefCounted
## Read-only view of the world through one NPC's eyes, implementing the read rule (R5.4):
## facts about the NPC itself and public facts come from world state; everything else comes from
## the NPC's beliefs, a missing belief reading as the declared default with confidence 0.
## A truth view (used by the executor at action start, R5.5) reads world state for every fact.
## Hooks receive views and may only call their public methods.

var _world: NpcfWorld
var _npc: StringName
var _truth: bool


func _init(world: NpcfWorld, npc: StringName, truth: bool = false) -> void:
	_world = world
	_npc = npc
	_truth = truth


func npc_id() -> StringName:
	return _npc


func is_truth_view() -> bool:
	return _truth


func tick() -> int:
	return _world.clock.tick


func day() -> int:
	return _world.clock.day()


func minute_of_day() -> int:
	return _world.clock.minute_of_day()


func day_of_week() -> int:
	return _world.clock.day_of_week()


func minutes_per_tick() -> int:
	return _world.clock.minutes_per_tick


func player() -> StringName:
	return _world.sim.player_entity


## Reads one fact under the read rule.
func fact(subject: StringName, fact_id: StringName) -> NpcfFactRead:
	var read: NpcfFactRead = _read(subject, fact_id)
	if _world.audit != null and _world.audit.reading:
		_world.audit.on_read(_npc, subject, fact_id, read.source, _truth, _world.clock.tick)
	return read


func _read(subject: StringName, fact_id: StringName) -> NpcfFactRead:
	var def: NpcfFactDef = _world.state.fact_def(fact_id)
	if def == null:
		return NpcfFactRead.make(null, 0, NpcfBelief.Source.DEFAULT)
	if _truth or subject == _npc or def.public:
		return NpcfFactRead.make(_world.state.get_fact(subject, fact_id), 100, NpcfBelief.Source.TRUTH)
	var npc: NpcfNpcState = _world.npcs.get(_npc)
	var b: NpcfBelief = npc.beliefs.get_belief(subject, fact_id) if npc != null else null
	if b == null:
		return NpcfFactRead.make(def.default_value, 0, NpcfBelief.Source.DEFAULT)
	return NpcfFactRead.make(b.value, b.confidence, b.source)


## The value of `fact(subject, fact_id)`.
func fact_value(subject: StringName, fact_id: StringName) -> Variant:
	return fact(subject, fact_id).value


## This NPC's own relationship value toward `other` in one dimension (own relationships are always known).
func relationship(other: StringName, dim: StringName) -> int:
	return _world.relationships.value(_world, _npc, other, dim)


## The band of this NPC's relationship value toward `other`, or &"" when no band contains it.
func relationship_band(other: StringName, dim: StringName) -> StringName:
	return _world.relationships.band(_world, _npc, other, dim)


## This NPC's need value (needs are private to their owner).
func need(need_id: StringName) -> int:
	var npc: NpcfNpcState = _world.npcs.get(_npc)
	return npc.needs.get(need_id, 0) if npc != null else 0


## This NPC's need value normalized to 0..1 by the need's bounds.
func need_normalized(need_id: StringName) -> float:
	var def: NpcfNeedDef = _world.pack.needs.get(need_id)
	if def == null or def.max_value <= def.min_value:
		return 0.0
	return clampf(float(need(need_id) - def.min_value) / float(def.max_value - def.min_value), 0.0, 1.0)


func has_need(need_id: StringName) -> bool:
	var npc: NpcfNpcState = _world.npcs.get(_npc)
	return npc != null and npc.needs.has(need_id)


## Tags of any NPC (tags are public).
func tags_of(entity: StringName) -> Array[StringName]:
	var npc: NpcfNpcState = _world.npcs.get(entity)
	return npc.tags.duplicate() if npc != null else []


func has_tag(tag: StringName) -> bool:
	var npc: NpcfNpcState = _world.npcs.get(_npc)
	return npc != null and npc.tags.has(tag)


## This NPC's own location (truth: an NPC knows where it is).
func location() -> StringName:
	return _world.location_of(_npc)


## Where this NPC believes `entity` is (truth for itself), or &"" if unknown.
func location_of(entity: StringName) -> StringName:
	var v: Variant = fact(entity, NpcfFramework.AT).value
	if typeof(v) == TYPE_STRING_NAME:
		var s: StringName = v
		return s
	return &""


## Static map information: a location's tags.
func location_tags(location_id: StringName) -> Array[StringName]:
	var def: NpcfLocationDef = _world.pack.locations.get(location_id)
	return def.tags.duplicate() if def != null else []


## Path travel time in ticks between two locations, or -1 if unreachable.
func travel_ticks(from: StringName, to: StringName) -> int:
	return _world.pack.location_index.travel_ticks(from, to)


## The location with `tag` nearest to `from` by travel time (ties by ID), or &"".
func nearest_with_tag(from: StringName, tag: StringName) -> StringName:
	return _world.pack.location_index.nearest_with_tag(from, tag)


func current_goal() -> StringName:
	var npc: NpcfNpcState = _world.npcs.get(_npc)
	return npc.current_goal if npc != null else &""


## The running action's ID, or &"".
func running_action() -> StringName:
	var npc: NpcfNpcState = _world.npcs.get(_npc)
	return npc.running.call.action if npc != null and npc.is_busy() else &""


## A view of the same NPC that reads ground truth.
func as_truth() -> NpcfNpcView:
	return NpcfNpcView.new(_world, _npc, true)


## The NPC's display name (its ID when it has none).
func display_name() -> String:
	var n: NpcfNpcState = _world.npcs.get(_npc)
	if n != null and n.resolved != null and n.resolved.display_name != "":
		return n.resolved.display_name
	return String(_npc)


## Persona text for dialogue: the resolved voice of the personalities and the character (R4.5).
func persona() -> String:
	var n: NpcfNpcState = _world.npcs.get(_npc)
	return n.resolved.voice if n != null and n.resolved != null else ""
