class_name NpcfLineResult
extends RefCounted
## What a line generator returns. ok = false means "use the authored line"; failure names the category
## (timeout, http, parse, schema, banned, citation, action, no_template, busy, off).

var ok: bool = false
var text: String = ""
var source: StringName = &""
var failure: StringName = &""
var validation_failures: Array[StringName] = []
## A validated dialogue-tier action, or null.
var action: NpcfActionCall = null
## Handles of the facts the line cites.
var cited: Array[StringName] = []
var latency_ms: int = 0


static func failed(category: StringName, p_latency_ms: int = 0) -> NpcfLineResult:
	var r: NpcfLineResult = NpcfLineResult.new()
	r.ok = false
	r.failure = category
	r.latency_ms = p_latency_ms
	return r
