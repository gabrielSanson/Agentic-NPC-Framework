class_name NpcfInput
extends RefCounted
## Something the game or an adapter reports between ticks. Inputs are applied in arrival order at
## the start of the next tick (phase 2, R14.4).

enum Kind { EVENT, ACTION_FINISHED, ARRIVED, MOVE_FAILED, EMBODIED, DISEMBODIED, CONVERSATION, START_ACTION }

var kind: int = Kind.EVENT
var npc: StringName = &""
var call_id: int = -1
## For ACTION_FINISHED: true when the action succeeded.
var success: bool = true
var reason: StringName = &""
var location: StringName = &""
var event: NpcfEvent = null
## For CONVERSATION: the rule outcome's changes, applied after the event is committed.
var changes: Array[NpcfStateChange] = []
## For START_ACTION: the dialogue-tier action to start for `npc`.
var call: NpcfActionCall = null


static func event_input(e: NpcfEvent) -> NpcfInput:
	var i: NpcfInput = NpcfInput.new()
	i.kind = Kind.EVENT
	i.event = e
	return i


static func arrived(entity: StringName, p_location: StringName) -> NpcfInput:
	var i: NpcfInput = NpcfInput.new()
	i.kind = Kind.ARRIVED
	i.npc = entity
	i.location = p_location
	return i


static func action_finished(p_npc: StringName, p_call_id: int, p_success: bool, p_reason: StringName = &"") -> NpcfInput:
	var i: NpcfInput = NpcfInput.new()
	i.kind = Kind.ACTION_FINISHED
	i.npc = p_npc
	i.call_id = p_call_id
	i.success = p_success
	i.reason = p_reason
	return i


static func move_failed(p_npc: StringName, p_call_id: int, p_reason: StringName) -> NpcfInput:
	var i: NpcfInput = NpcfInput.new()
	i.kind = Kind.MOVE_FAILED
	i.npc = p_npc
	i.call_id = p_call_id
	i.reason = p_reason
	return i


static func embodiment(p_npc: StringName, embodied: bool) -> NpcfInput:
	var i: NpcfInput = NpcfInput.new()
	i.kind = Kind.EMBODIED if embodied else Kind.DISEMBODIED
	i.npc = p_npc
	return i


## A dialogue turn's conversation event, with the rule outcome's changes (applied in phase 2).
static func conversation(e: NpcfEvent, p_changes: Array[NpcfStateChange]) -> NpcfInput:
	var i: NpcfInput = NpcfInput.new()
	i.kind = Kind.CONVERSATION
	i.event = e
	i.changes = p_changes
	return i


## A dialogue-tier action to start at the next tick (phase 2).
static func start_action(c: NpcfActionCall) -> NpcfInput:
	var i: NpcfInput = NpcfInput.new()
	i.kind = Kind.START_ACTION
	i.npc = c.npc
	i.call = c
	return i
