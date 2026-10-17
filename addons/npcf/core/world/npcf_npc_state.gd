class_name NpcfNpcState
extends RefCounted
## Everything the simulation holds for one NPC.

var id: StringName = &""
var resolved: NpcfResolvedCharacter = null
var needs: Dictionary[StringName, int] = {}
var tags: Array[StringName] = []
var current_goal: StringName = &""
## Remaining plan steps after the running one.
var plan: Array[NpcfActionCall] = []
var running: NpcfRunningAction = null
## Action ID -> first tick the action is allowed again.
var cooldowns: Dictionary[StringName, int] = {}
## Goal ID -> first tick the goal is considered again after a planning or movement failure.
var unreachable_until: Dictionary[StringName, int] = {}
## Reaction rule ID -> first tick the rule may fire again.
var reaction_cooldowns: Dictionary[StringName, int] = {}
var next_periodic_tick: int = 0
var beliefs: NpcfBeliefStore = NpcfBeliefStore.new()
var memory: NpcfMemoryLog = NpcfMemoryLog.new()
var last_addressed_tick: int = -1
## Ring buffers for traces.
var decision_records: Array[NpcfDecisionRecord] = []
var action_outcomes: Array[NpcfActionOutcome] = []


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func is_busy() -> bool:
	return running != null and not running.finished
