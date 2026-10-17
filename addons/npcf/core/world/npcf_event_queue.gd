class_name NpcfEventQueue
extends RefCounted
## Validates and records events (R3.5). Every committed event goes to the log and waits for the
## next delivery phase.

var next_id: int = 1
var log: Array[NpcfEvent] = []
var undelivered: Array[NpcfEvent] = []
## Reason the last emit was rejected, empty when it succeeded.
var last_error: String = ""
## When false, the log is not kept (delivery still works). Long in-game runs may turn it off.
var keep_log: bool = true

var _kinds: Dictionary[StringName, NpcfEventKindDef] = {}


func _init(kinds: Dictionary[StringName, NpcfEventKindDef] = {}) -> void:
	_kinds = kinds


func kind_def(kind: StringName) -> NpcfEventKindDef:
	return _kinds.get(kind)


## Validates `e` against its kind, stamps ID, tick, salience and visibility, and commits it.
## Returns the event ID, or -1 with `last_error` set (`unknown event kind "x"`, `field ...`).
func emit(e: NpcfEvent, tick: int) -> int:
	last_error = validate(e)
	if last_error != "":
		return -1
	var def: NpcfEventKindDef = _kinds[e.kind]
	e.id = next_id
	next_id += 1
	e.tick = tick
	e.salience = def.salience
	e.visibility = def.visibility
	if keep_log:
		log.append(e)
	undelivered.append(e)
	return e.id


## Returns an empty string when `e` is valid, else the reason.
func validate(e: NpcfEvent) -> String:
	var def: NpcfEventKindDef = _kinds.get(e.kind)
	if def == null:
		return "unknown event kind \"%s\"" % e.kind
	var reason: String = NpcfFieldDef.validate(def.payload_fields, e.payload)
	if reason != "":
		return "%s: %s" % [e.kind, reason]
	return ""


## Takes every event committed since the last call.
func take_undelivered() -> Array[NpcfEvent]:
	var out: Array[NpcfEvent] = undelivered
	undelivered = []
	return out


## The log as JSON lines, one event per line, keys sorted (used by determinism tests).
func log_text() -> String:
	var lines: PackedStringArray = []
	for e: NpcfEvent in log:
		lines.append(JSON.stringify(e.to_dict(), "", true, true))
	return "\n".join(lines)
