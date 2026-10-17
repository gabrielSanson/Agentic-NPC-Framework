class_name NpcfHookRunner
extends RefCounted
## The only way pack code runs inside the core (R2.4, R18). Calls a hook through Callable.callv,
## detects runtime errors with NpcfErrorProbe, validates the returned value's type, range and
## finiteness, and returns the documented safe default on any failure. Every failure is counted
## once per call per hook script, and logged with pack, hook, NPC and tick unless log_failures is off.
##
## An infinite loop inside a hook cannot be isolated; packs are trusted code (README threat model).

## Current tick, set by the world at the start of each step (for failure logs).
var tick: int = 0
## Failure count per hook script path.
var failures: Dictionary[String, int] = {}
## When false, failures are counted but not pushed as warnings (tests of expected failures).
var log_failures: bool = true

var _pack_namespace: StringName = &""
var _instances: Dictionary[String, RefCounted] = {}
var _probe: NpcfErrorProbe = NpcfErrorProbe.new()
var _probe_registered: bool = false
## Set by _call: true when the last call failed (its failure is already counted).
var _errored: bool = false


func _init(pack_namespace: StringName = &"") -> void:
	_pack_namespace = pack_namespace
	OS.add_logger(_probe)
	_probe_registered = true


## Unregisters the error probe. The world calls this when it is disposed.
func dispose() -> void:
	if _probe_registered:
		OS.remove_logger(_probe)
		_probe_registered = false


## The shared instance of a hook script (hooks are stateless; one instance per script), or null
## when the script cannot be instantiated.
func instance(script: Script) -> RefCounted:
	var key: String = script.resource_path if script.resource_path != "" else str(script.get_instance_id())
	var inst: RefCounted = _instances.get(key)
	if inst == null and not needs_constructor_args(script):
		var obj: Variant = script.call("new")
		if obj is RefCounted:
			inst = obj
			_instances[key] = inst
	return inst


## True when the script's constructor has parameters without defaults. Such a hook cannot be
## instantiated with no arguments, and instantiating it anyway aborts the engine, so it is checked first.
static func needs_constructor_args(script: Script) -> bool:
	for m: Dictionary in script.get_script_method_list():
		if m["name"] == "_init":
			var margs: Array = m["args"]
			var defaults: Array = m["default_args"]
			return margs.size() > defaults.size()
	return false


## A utility input in 0..1. Safe default 0.0.
func consideration(hook: Script, view: NpcfNpcView, params: NpcfHookParams) -> float:
	var r: Variant = _call(hook, &"evaluate", [view, params], view.npc_id())
	if _errored:
		return 0.0
	if not (r is float or r is int):
		_fail(hook, view.npc_id(), "returned %s, expected a number" % type_string(typeof(r)))
		return 0.0
	var f: float = r
	if is_finite(f) and f >= 0.0 and f <= 1.0:
		return f
	_fail(hook, view.npc_id(), "returned %s, outside 0..1" % str(r))
	return 0.0


## A condition result. Safe default false.
func condition(hook: Script, view: NpcfNpcView, args: Dictionary[StringName, Variant]) -> bool:
	var r: Variant = _call(hook, &"check", [view, args], view.npc_id())
	if _errored:
		return false
	if not (r is bool):
		_fail(hook, view.npc_id(), "returned %s, expected a bool" % type_string(typeof(r)))
		return false
	var ok: bool = r
	return ok


## The computed changes, or null when the hook failed (the action then fails with `hook_error`).
func effect(hook: Script, view: NpcfNpcView, args: Dictionary[StringName, Variant]) -> Variant:
	var r: Variant = _call(hook, &"compute", [view, args], view.npc_id())
	if _errored:
		return null
	var out: Array[NpcfStateChange] = []
	if not _typed_array(r, out, hook, view.npc_id()):
		return null
	return out


## Beliefs one receiver forms from an event. Safe default: no beliefs.
func mapper(hook: Script, event: NpcfEventView, receiver: StringName) -> Array[NpcfFact]:
	var r: Variant = _call(hook, &"map_event", [event, receiver], receiver)
	var out: Array[NpcfFact] = []
	if _errored:
		return out
	if not _typed_array(r, out, hook, receiver):
		return []
	return out


## RUNNING, SUCCESS or FAILURE (NpcfResolverHook constants); FAILURE on any failure.
func resolver(hook: Script, call_view: NpcfActionCallView, world: NpcfWorldView, elapsed: int) -> int:
	var r: Variant = _call(hook, &"resolve", [call_view, world, elapsed], call_view.npc())
	if _errored or not (r is int):
		if not _errored:
			_fail(hook, call_view.npc(), "returned %s, expected an int" % type_string(typeof(r)))
		return NpcfResolverHook.FAILURE
	var status: int = r
	if status == NpcfResolverHook.RUNNING or status == NpcfResolverHook.SUCCESS or status == NpcfResolverHook.FAILURE:
		return status
	_fail(hook, call_view.npc(), "returned %d, not RUNNING, SUCCESS or FAILURE" % status)
	return NpcfResolverHook.FAILURE


## A plan. Null is a legitimate "no plan" and is not a failure; any other wrong type is one.
func planner(hook: Script, goal: NpcfGoalDef, view: NpcfNpcView, legal: NpcfLegalActions, budget: NpcfPlanBudget) -> NpcfPlan:
	var r: Variant = _call(hook, &"plan", [goal, view, legal, budget], view.npc_id())
	if _errored or r == null:
		return null
	if not (r is NpcfPlan):
		_fail(hook, view.npc_id(), "returned %s, expected an NpcfPlan or null" % type_string(typeof(r)))
		return null
	var p: NpcfPlan = r
	return p


## Invariant failures. Safe default: one failure with the message "hook_error".
func invariant(hook: Script, world: NpcfWorldView, invariant_id: StringName) -> Array[NpcfInvariantFailure]:
	var r: Variant = _call(hook, &"check", [world], &"")
	var out: Array[NpcfInvariantFailure] = []
	if not _errored and _typed_array(r, out, hook, &""):
		return out
	var failed: Array[NpcfInvariantFailure] = []
	failed.append(NpcfInvariantFailure.make(invariant_id, tick, [] as Array[StringName], "hook_error"))
	return failed


## Calls `method` on the hook instance. Returns the raw result, or null when the call failed; in that
## case `_errored` is set and the failure is already counted.
func _call(hook: Script, method: StringName, args: Array, npc: StringName) -> Variant:
	_errored = false
	var inst: RefCounted = instance(hook)
	if inst == null or not inst.has_method(method):
		_errored = true
		_fail(hook, npc, "cannot instantiate or has no method %s" % method)
		return null
	var before: int = _probe.script_errors
	var r: Variant = Callable(inst, method).callv(args)
	if _probe.script_errors != before:
		_errored = true
		_fail(hook, npc, "runtime error: " + _probe.last_message)
		return null
	return r


## True when `r` is an array whose elements all have the type of `out`. Otherwise counts a failure.
func _typed_array(r: Variant, out: Array, hook: Script, npc: StringName) -> bool:
	if not (r is Array):
		_fail(hook, npc, "returned %s, expected an array" % type_string(typeof(r)))
		return false
	var arr: Array = r
	for item: Variant in arr:
		if not is_instance_of(item, out.get_typed_script()):
			_fail(hook, npc, "returned an array with an element of the wrong type")
			return false
	out.assign(arr)
	return true


func _fail(hook: Script, npc: StringName, reason: String) -> void:
	var key: String = hook.resource_path
	failures[key] = failures.get(key, 0) + 1
	if log_failures:
		push_warning("npcf hook failure: pack=%s hook=%s npc=%s tick=%d reason=%s" % [_pack_namespace, key, npc, tick, reason])


## Total failures of one hook script.
func failure_count(hook: Script) -> int:
	return failures.get(hook.resource_path, 0)
