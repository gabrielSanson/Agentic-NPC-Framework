class_name NpcfBeliefMeta
extends RefCounted
## Provenance attached to facts when they are stored as beliefs.

var source: int = NpcfBelief.Source.WITNESSED
var teller: StringName = &""
var tellers: Array[StringName] = []
var tick: int = 0
var event_id: int = -1
var salience: int = 0
var confidence: int = 100
