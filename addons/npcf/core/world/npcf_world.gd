class_name NpcfWorld
extends RefCounted
## The simulation world: owns all state and service instances and runs the eight-phase tick
## (R1.1). Built only by NpcfWorldBuilder. Services take the world as their first parameter and
## never hold it, so there are no reference cycles.

var pack: NpcfLoadedPack
var sim: NpcfSimConfig
var scenario: NpcfScenarioDef
var clock: NpcfClock
var rng: NpcfRng
var events: NpcfEventQueue
var state: NpcfWorldState
var hooks: NpcfHookRunner
var adapters: NpcfAdapterSet
var npcs: Dictionary[StringName, NpcfNpcState] = {}
var npc_ids: Array[StringName] = []          # sorted
var occupancy: NpcfOccupancy                  # NPCs by location, mirrors npcf.at
var headless: bool = true                     # invariants every tick when true
var next_call_id: int = 1
var inputs: Array[NpcfInput] = []
# services
var applier: NpcfEffectApplier
var need_system: NpcfNeedSystem
var delivery: NpcfDelivery
var action_registry: NpcfActionRegistry
var executor: NpcfExecutor
var travel: NpcfTravelResolver
var scorer: NpcfUtilityScorer
var directives: NpcfDirectiveBoard
var selector: NpcfGoalSelector
var reactions: NpcfReactionRules
var scheduler: NpcfDecisionScheduler
var invariants: NpcfInvariants
var relationships: NpcfRelationships
var tags: NpcfTags
var rumors: NpcfRumors
var director: NpcfDirector
var dialogue: NpcfDialogueService
## Optional per-phase callbacks for tests: phase name -> Callable(world). Empty by default.
var phase_probes: Dictionary[StringName, Callable] = {}

## True when the calendar day changed during the current tick's clock phase.
var _day_changed: bool = false


## Runs one tick through the eight phases in order and returns what happened.
func step() -> NpcfTickReport:
	var report: NpcfTickReport = NpcfTickReport.new()

	# 1. clock
	var day_before: int = clock.day()
	clock.advance()
	hooks.tick = clock.tick
	report.tick = clock.tick
	_day_changed = clock.day() != day_before
	_finish_phase(&"clock", report)

	# 2. inputs: applied in arrival order.
	var batch: Array[NpcfInput] = inputs
	inputs = []
	for i: NpcfInput in batch:
		_apply_input(i)
	_finish_phase(&"inputs", report)

	# 3. director: expires directives, then applies last tick's events and emits directives
	director.step(self)
	_finish_phase(&"director", report)

	# 4. needs (beliefs decay once per day change)
	need_system.tick(self)
	if _day_changed:
		delivery.decay_beliefs(self)
	tags.evaluate_transitions(self)
	_finish_phase(&"needs", report)

	# 5. actions
	executor.advance(self, report)
	_finish_phase(&"actions", report)

	# 6. delivery of events emitted in phases 2-5
	delivery.deliver_pending(self)
	_finish_phase(&"delivery", report)

	# 7. decisions
	var due: Array[StringName] = scheduler.take_due(self, sim.max_decisions_per_tick)
	for id: StringName in due:
		selector.decide(self, id, report)
	report.decisions = due.size()
	_finish_phase(&"decisions", report)

	# 8. checks
	if headless or clock.tick % maxi(1, sim.invariant_interval_ticks) == 0:
		report.invariant_failures = invariants.check(self)
	_finish_phase(&"checks", report)
	return report


## Queues an input for the next tick's phase 2.
func queue_input(input: NpcfInput) -> void:
	inputs.append(input)


## Commits an event at the current tick. Returns the event ID, or -1 (see events.last_error).
func emit(e: NpcfEvent) -> int:
	return events.emit(e, clock.tick)


## Where an entity is (fact npcf.at, truth), or &"" when unset.
func location_of(entity: StringName) -> StringName:
	var v: Variant = state.get_fact(entity, NpcfFramework.AT)
	if typeof(v) == TYPE_STRING_NAME:
		var s: StringName = v
		return s
	return &""


## The NPC state, or null when `id` is not an NPC.
func npc(id: StringName) -> NpcfNpcState:
	var n: NpcfNpcState = npcs.get(id)
	return n


## An NPC's view of the world (read rule applies).
func view(npc_id: StringName) -> NpcfNpcView:
	return NpcfNpcView.new(self, npc_id)


func world_view() -> NpcfWorldView:
	return NpcfWorldView.new(self)


## True for an NPC or the player entity.
func is_entity(id: StringName) -> bool:
	return npcs.has(id) or (sim.player_entity != &"" and id == sim.player_entity)


## Releases hooks and services. Call before dropping the world.
func dispose() -> void:
	if dialogue != null:
		dialogue.dispose()
	dialogue = null
	hooks.dispose()
	npcs.clear()
	occupancy = null
	applier = null
	need_system = null
	delivery = null
	action_registry = null
	executor = null
	travel = null
	scorer = null
	directives = null
	selector = null
	reactions = null
	scheduler = null
	invariants = null
	relationships = null
	tags = null
	rumors = null
	director = null


func _apply_input(i: NpcfInput) -> void:
	match i.kind:
		NpcfInput.Kind.EVENT:
			if i.event != null:
				emit(i.event)
		NpcfInput.Kind.ACTION_FINISHED:
			executor.on_finished(self, i)
		NpcfInput.Kind.ARRIVED:
			travel.on_arrived(self, i.npc, i.location)
		NpcfInput.Kind.MOVE_FAILED:
			executor.on_move_failed(self, i)
		NpcfInput.Kind.EMBODIED, NpcfInput.Kind.DISEMBODIED:
			travel.on_embodiment(self, i.npc, i.kind == NpcfInput.Kind.EMBODIED)
		NpcfInput.Kind.CONVERSATION:
			if i.event != null:
				var id: int = emit(i.event)
				if id >= 0 and not i.changes.is_empty():
					var reason: String = applier.apply(self, i.changes, id)
					if reason != "":
						push_warning("npcf: conversation changes refused: " + reason)
		NpcfInput.Kind.START_ACTION:
			if i.call != null:
				i.call.decision_tick = clock.tick
				# Dialogue actions are best-effort presentation; a refusal is not an error.
				executor.start(self, i.npc, i.call)


func _finish_phase(phase: StringName, report: NpcfTickReport) -> void:
	report.phases.append(phase)
	if phase_probes.has(phase):
		var probe: Callable = phase_probes[phase]
		probe.call(self)
