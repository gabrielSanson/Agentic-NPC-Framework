extends GdUnitTestSuite
## Hook runner: good hooks return their values, every bad hook returns its documented safe default
## and is counted exactly once per call.
##
## Spike result (task 6, Godot 4.5.2 and 4.7.2, --headless): a runtime error inside a function called
## through Callable.callv does NOT make the call return null. The function is aborted and the caller
## gets the declared return type's default (0.0, false, 0, an empty array, or null for objects), and
## execution continues. Return-value checks alone therefore cannot see most hook failures. Godot 4.5
## added the Logger API, which reports every script error synchronously, so the runner compares
## this probe's counter before and after each hook call.
##
## Calls that trigger a script error are wrapped in assert_error(...).is_runtime_error(message), which
## also consumes the error so gdUnit does not report it as a test error.

const HOOKS: String = "res://tests/fixtures/hooks/"
const FAILED: int = NpcfResolverHook.FAILURE
const CALL_ON_NIL_CONSIDERATION: String = "Invalid call. Nonexistent function 'npc_id' in base 'Nil'."
const CALL_ON_NIL_KIND: String = "Invalid call. Nonexistent function 'kind' in base 'Nil'."
const CALL_ON_NIL_TICK: String = "Invalid call. Nonexistent function 'tick' in base 'Nil'."
const CALL_ON_NIL_CALL_ID: String = "Invalid call. Nonexistent function 'call_id' in base 'Nil'."
const PROPERTY_ON_NIL: String = "Invalid access to property or key 'max_steps' on a base object of type 'Nil'."
const RETURN_NIL_ARRAY: String = "Trying to return a value of type \"Nil\" from a function whose return type is \"Array[Object]\"."
const RETURN_NIL_BOOL: String = "Trying to return a value of type \"Nil\" from a function whose return type is \"bool\"."
const RETURN_STRING_FLOAT: String = "Trying to return a value of type \"String\" from a function whose return type is \"float\"."
const RETURN_ARRAY_CHANGES: String = "Trying to return a value of type \"Array\" from a function whose return type is \"Array[NpcfStateChange]\"."

var _runners: Array[NpcfHookRunner] = []


func after_test() -> void:
	for r: NpcfHookRunner in _runners:
		r.dispose()
	_runners.clear()


func _runner() -> NpcfHookRunner:
	var r: NpcfHookRunner = NpcfHookRunner.new(&"toy")
	r.log_failures = false
	_runners.append(r)
	return r


func _hook(file: String) -> Script:
	return load(HOOKS + file) as Script


func _npc_view() -> NpcfNpcView:
	return NpcfNpcView.new(NpcfWorld.new(), &"toy.ana")


func _world_view() -> NpcfWorldView:
	return NpcfWorldView.new(NpcfWorld.new())


func _event() -> NpcfEventView:
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = &"npcf.arrived"
	return NpcfEventView.new(e)


func _call_view() -> NpcfActionCallView:
	return NpcfActionCallView.new(NpcfActionCall.new(), null)


## Runs `hook_call` and expects exactly one script error with `message`. Returns the call's result.
func _expect_error(message: String, hook_call: Callable) -> Variant:
	var holder: Array = [null]
	await assert_error(func() -> void: holder[0] = hook_call.call()).is_runtime_error(message)
	return holder[0]


func test_good_hooks_return_their_values() -> void:
	var r: NpcfHookRunner = _runner()
	var view: NpcfNpcView = _npc_view()

	var c: float = r.consideration(_hook("ok_consideration.gd"), view, NpcfHookParams.new())
	assert_float(c).is_equal(0.75)
	assert_bool(r.condition(_hook("ok_condition.gd"), view, {})).is_true()

	var raw_changes: Variant = r.effect(_hook("ok_effect.gd"), view, {})
	var changes: Array[NpcfStateChange] = raw_changes
	assert_int(changes.size()).is_equal(1)
	assert_str(String(changes[0].subject)).is_equal("npcf.global")

	var facts: Array[NpcfFact] = r.mapper(_hook("ok_mapper.gd"), _event(), &"toy.ana")
	assert_int(facts.size()).is_equal(1)
	var fact_value: bool = facts[0].value
	assert_bool(fact_value).is_true()

	var plan: NpcfPlan = r.planner(_hook("ok_planner.gd"), NpcfGoalDef.new(), view, NpcfLegalActions.new(), NpcfPlanBudget.new())
	assert_str(String(plan.planner)).is_equal("toy.fixture")

	var failures: Array[NpcfInvariantFailure] = r.invariant(_hook("ok_invariant.gd"), _world_view(), &"toy.inv.ok")
	assert_int(failures.size()).is_equal(0)

	var resolver: Script = _hook("ok_resolver.gd")
	assert_int(r.resolver(resolver, _call_view(), _world_view(), 0)).is_equal(NpcfResolverHook.RUNNING)
	assert_int(r.resolver(resolver, _call_view(), _world_view(), 3)).is_equal(NpcfResolverHook.SUCCESS)

	assert_int(r.failures.size()).is_equal(0)


func test_runtime_error_consideration_returns_zero() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("error_consideration.gd")
	var v: float = await _expect_error(CALL_ON_NIL_CONSIDERATION,
			func() -> float: return r.consideration(hook, _npc_view(), NpcfHookParams.new()))
	assert_float(v).is_equal(0.0)
	assert_int(r.failure_count(hook)).is_equal(1)


func test_runtime_error_condition_returns_false() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("error_condition.gd")
	var v: bool = await _expect_error(CALL_ON_NIL_CONSIDERATION,
			func() -> bool: return r.condition(hook, _npc_view(), {}))
	assert_bool(v).is_false()
	assert_int(r.failure_count(hook)).is_equal(1)


func test_runtime_error_effect_returns_null() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("error_effect.gd")
	var v: Variant = await _expect_error(CALL_ON_NIL_CONSIDERATION,
			func() -> Variant: return r.effect(hook, _npc_view(), {}))
	assert_object(v).is_null()
	assert_int(r.failure_count(hook)).is_equal(1)


func test_runtime_error_mapper_returns_no_beliefs() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("error_mapper.gd")
	var facts: Array[NpcfFact] = await _expect_error(CALL_ON_NIL_KIND,
			func() -> Array[NpcfFact]: return r.mapper(hook, _event(), &"toy.ana"))
	assert_int(facts.size()).is_equal(0)
	assert_int(r.failure_count(hook)).is_equal(1)


func test_runtime_error_planner_returns_no_plan() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("error_planner.gd")
	var plan: NpcfPlan = await _expect_error(PROPERTY_ON_NIL,
			func() -> NpcfPlan: return r.planner(hook, NpcfGoalDef.new(), _npc_view(), NpcfLegalActions.new(), NpcfPlanBudget.new()))
	assert_object(plan).is_null()
	assert_int(r.failure_count(hook)).is_equal(1)


func test_runtime_error_invariant_reports_hook_error() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("error_invariant.gd")
	var failures: Array[NpcfInvariantFailure] = await _expect_error(CALL_ON_NIL_TICK,
			func() -> Array[NpcfInvariantFailure]: return r.invariant(hook, _world_view(), &"toy.inv.x"))
	assert_int(failures.size()).is_equal(1)
	assert_str(failures[0].message).is_equal("hook_error")
	assert_int(r.failure_count(hook)).is_equal(1)


func test_runtime_error_resolver_returns_failure() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("error_resolver.gd")
	var status: int = await _expect_error(CALL_ON_NIL_CALL_ID,
			func() -> int: return r.resolver(hook, _call_view(), _world_view(), 0))
	assert_int(status).is_equal(FAILED)
	assert_int(r.failure_count(hook)).is_equal(1)


func test_null_results_return_defaults_and_count_once() -> void:
	var r: NpcfHookRunner = _runner()
	var view: NpcfNpcView = _npc_view()

	var null_effect: Script = _hook("null_effect.gd")
	var effect: Variant = await _expect_error(RETURN_NIL_ARRAY,
			func() -> Variant: return r.effect(null_effect, view, {}))
	assert_object(effect).is_null()
	assert_int(r.failure_count(null_effect)).is_equal(1)

	var null_mapper: Script = _hook("null_mapper.gd")
	var facts: Array[NpcfFact] = await _expect_error(RETURN_NIL_ARRAY,
			func() -> Array[NpcfFact]: return r.mapper(null_mapper, _event(), &"toy.ana"))
	assert_int(facts.size()).is_equal(0)
	assert_int(r.failure_count(null_mapper)).is_equal(1)

	var null_invariant: Script = _hook("null_invariant.gd")
	var failures: Array[NpcfInvariantFailure] = await _expect_error(RETURN_NIL_ARRAY,
			func() -> Array[NpcfInvariantFailure]: return r.invariant(null_invariant, _world_view(), &"toy.inv.n"))
	assert_str(failures[0].message).is_equal("hook_error")
	assert_int(r.failure_count(null_invariant)).is_equal(1)

	# A plan of null means "no plan", which is an answer and not a failure.
	var null_planner: Script = _hook("null_planner.gd")
	assert_object(r.planner(null_planner, NpcfGoalDef.new(), view, NpcfLegalActions.new(), NpcfPlanBudget.new())).is_null()
	assert_int(r.failure_count(null_planner)).is_equal(0)


func test_wrong_type_results_return_defaults_and_count_once() -> void:
	var r: NpcfHookRunner = _runner()
	var view: NpcfNpcView = _npc_view()

	var wrong_condition: Script = _hook("wrong_type_condition.gd")
	var b: bool = await _expect_error(RETURN_NIL_BOOL,
			func() -> bool: return r.condition(wrong_condition, view, {}))
	assert_bool(b).is_false()
	assert_int(r.failure_count(wrong_condition)).is_equal(1)

	var wrong_consideration: Script = _hook("wrong_type_consideration.gd")
	var c: float = await _expect_error(RETURN_STRING_FLOAT,
			func() -> float: return r.consideration(wrong_consideration, view, NpcfHookParams.new()))
	assert_float(c).is_equal(0.0)
	assert_int(r.failure_count(wrong_consideration)).is_equal(1)

	var wrong_effect: Script = _hook("wrong_type_effect.gd")
	var effect: Variant = await _expect_error(RETURN_ARRAY_CHANGES,
			func() -> Variant: return r.effect(wrong_effect, view, {}))
	assert_object(effect).is_null()
	assert_int(r.failure_count(wrong_effect)).is_equal(1)


func test_out_of_range_and_bad_status_return_defaults_and_count_once() -> void:
	var r: NpcfHookRunner = _runner()
	var view: NpcfNpcView = _npc_view()

	var nan_hook: Script = _hook("nan_consideration.gd")
	assert_float(r.consideration(nan_hook, view, NpcfHookParams.new())).is_equal(0.0)
	assert_int(r.failure_count(nan_hook)).is_equal(1)

	var range_hook: Script = _hook("out_of_range_consideration.gd")
	assert_float(r.consideration(range_hook, view, NpcfHookParams.new())).is_equal(0.0)
	assert_int(r.failure_count(range_hook)).is_equal(1)

	var status_hook: Script = _hook("bad_status_resolver.gd")
	assert_int(r.resolver(status_hook, _call_view(), _world_view(), 0)).is_equal(FAILED)
	assert_int(r.failure_count(status_hook)).is_equal(1)


func test_scripts_that_are_not_usable_hooks_fail_once() -> void:
	var r: NpcfHookRunner = _runner()
	var view: NpcfNpcView = _npc_view()

	var not_a_hook: Script = _hook("not_a_hook.gd")
	assert_bool(r.condition(not_a_hook, view, {})).is_false()
	assert_int(r.failure_count(not_a_hook)).is_equal(1)

	var needs_args: Script = _hook("needs_args_condition.gd")
	assert_bool(r.condition(needs_args, view, {})).is_false()
	assert_int(r.failure_count(needs_args)).is_equal(1)


func test_failures_are_counted_per_hook_script() -> void:
	var r: NpcfHookRunner = _runner()
	var hook: Script = _hook("out_of_range_consideration.gd")
	for _i: int in 3:
		r.consideration(hook, _npc_view(), NpcfHookParams.new())
	assert_int(r.failure_count(hook)).is_equal(3)
	assert_int(r.failure_count(_hook("ok_consideration.gd"))).is_equal(0)
	assert_int(r.failures.size()).is_equal(1)
