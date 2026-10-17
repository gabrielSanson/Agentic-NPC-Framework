class_name NpcfDirector
extends RefCounted
## World-level pressure (R12): macro variables updated from committed events, rules that emit tag-targeted
## directives into the directive board. Directives only bias utility (R12.3). Runs in phase 3.


## One macro delta of an event kind: which macro, and by how much.
class Step extends RefCounted:
	var macro: StringName = &""
	var amount: float = 0.0


	func _init(p_macro: StringName, p_amount: float) -> void:
		macro = p_macro
		amount = p_amount


var _values: Dictionary[StringName, float] = {}
## Events delivered in the previous tick's phase 6, in ID order.
var _pending: Array[NpcfEvent] = []
## Rule ID -> expiry tick of the directive it last emitted.
var _active_until: Dictionary[StringName, int] = {}
## Event kind -> the macro deltas it causes, in pack order. Built in reset.
var _deltas_by_kind: Dictionary[StringName, Array] = {}


## (Re)initializes values from the pack (start) and the scenario (macro_start); clears pending and active state.
func reset(world: NpcfWorld) -> void:
	_values.clear()
	_pending.clear()
	_active_until.clear()
	_deltas_by_kind.clear()
	for m: NpcfMacroVarDef in world.pack.director.macros:
		if m == null:
			continue
		var start: float = m.start
		if world.scenario.macro_start.has(m.id):
			start = world.scenario.macro_start[m.id]
		_values[m.id] = clampf(start, m.min_value, m.max_value)
		for d: NpcfMacroDelta in m.deltas:
			if d == null or d.event_kind == null:
				continue
			var kind: StringName = d.event_kind.id
			if not _deltas_by_kind.has(kind):
				var fresh: Array[Step] = []
				_deltas_by_kind[kind] = fresh
			var list: Array = _deltas_by_kind[kind]
			list.append(Step.new(m.id, d.amount))


## Called by delivery at the end of deliver_pending with that tick's batch.
func observe(batch: Array[NpcfEvent]) -> void:
	_pending.append_array(batch)


## Phase 3: directives.expire(tick); apply pending deltas (events in order, deltas in pack order, clamp);
## run due rules; run the hook when due.
func step(world: NpcfWorld) -> void:
	var tick: int = world.clock.tick
	world.directives.expire(tick)
	for e: NpcfEvent in _pending:
		if not _deltas_by_kind.has(e.kind):
			continue
		var steps: Array = _deltas_by_kind[e.kind]
		for s: Step in steps:
			_apply(world, s)
	_pending.clear()
	for rule: NpcfDirectorRuleDef in world.pack.director.rules:
		if rule == null or rule.goal == null or rule.target == null:
			continue
		if tick % maxi(1, rule.cadence_ticks) != 0:
			continue
		if _active_until.get(rule.id, -1) > tick:
			continue
		if not _conditions_hold(rule):
			continue
		var d: NpcfDirective = NpcfDirective.new()
		d.origin = rule.id
		d.target_tags_all = rule.target.tags_all.duplicate()
		d.target_tags_any = rule.target.tags_any.duplicate()
		d.target_tags_none = rule.target.tags_none.duplicate()
		d.goal = rule.goal.id
		d.priority = rule.priority
		d.expires_tick = tick + rule.duration_ticks
		world.directives.add(d)
		_active_until[rule.id] = d.expires_tick
	var hook: Script = world.pack.director.hook
	if hook != null and tick % maxi(1, world.pack.director.hook_cadence_ticks) == 0:
		_run_hook(world, hook, tick)


func value(id: StringName) -> float:
	return _values.get(id, 0.0)


func macro_view() -> NpcfMacroView:
	return NpcfMacroView.new(_values)


## Rule IDs whose directive is still active at `tick`, sorted.
func active_rules(tick: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _active_until:
		if _active_until[id] > tick:
			out.append(id)
	out.sort_custom(NpcfWorldState.name_less)
	return out


func _apply(world: NpcfWorld, s: Step) -> void:
	var def: NpcfMacroVarDef = world.pack.macros.get(s.macro)
	if def == null:
		return
	var current: float = _values.get(s.macro, def.start)
	_values[s.macro] = clampf(current + s.amount, def.min_value, def.max_value)


func _conditions_hold(rule: NpcfDirectorRuleDef) -> bool:
	for c: NpcfMacroCondition in rule.conditions:
		if c == null or c.macro == null:
			return false
		if not NpcfConditions.compare(value(c.macro.id), c.compare, c.value):
			return false
	return true


## The hook's specs become directives for pack goals with a priority in 0..1. A failing hook gives none.
func _run_hook(world: NpcfWorld, hook: Script, tick: int) -> void:
	var specs: Array[NpcfDirectiveSpec] = world.hooks.director(hook, macro_view(), tick)
	for s: NpcfDirectiveSpec in specs:
		if s == null or world.pack.goal(s.goal) == null:
			continue
		if not (s.priority >= 0.0 and s.priority <= 1.0):
			continue
		var d: NpcfDirective = NpcfDirective.new()
		d.origin = &"npcf.director_hook"
		d.target_tags_all = s.tags_all.duplicate()
		d.target_tags_any = s.tags_any.duplicate()
		d.target_tags_none = s.tags_none.duplicate()
		d.goal = s.goal
		d.priority = s.priority
		d.expires_tick = tick + s.duration_ticks
		world.directives.add(d)
