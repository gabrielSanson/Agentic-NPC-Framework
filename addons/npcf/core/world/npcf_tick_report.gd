class_name NpcfTickReport
extends RefCounted
## What happened in one tick, for the runtime's signals, the CLI and tests.

var tick: int = 0
## Phase names in the order they ran.
var phases: Array[StringName] = []
var started: Array[NpcfActionOutcome] = []
var finished: Array[NpcfActionOutcome] = []
var decisions: int = 0
var invariant_failures: Array[NpcfInvariantFailure] = []
