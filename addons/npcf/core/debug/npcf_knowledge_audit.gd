class_name NpcfKnowledgeAudit
extends RefCounted
## Debug-only recorder (R6.6). Off unless world.audit is set; never changes results. It records every fact read made
## while an NPC decides or a dialogue prompt is built, and every fact handed to a belief store. violations() reports
## the reads that no earlier delivery explains.

## One recorded read.
class Read extends RefCounted:
	var npc: StringName = &""
	var subject: StringName = &""
	var fact_id: StringName = &""
	var source: int = 0
	var truth: bool = false
	var context: StringName = &""
	var tick: int = 0

## True only between begin() and end(); reads are recorded only then.
var reading: bool = false
var context: StringName = &""
var reads: Array[Read] = []
var _delivered: Dictionary[String, int] = {}   # "npc|subject|fact" -> first tick delivered


func begin(p_context: StringName) -> void:
	reading = true
	context = p_context


func end() -> void:
	reading = false
	context = &""


func on_read(npc: StringName, subject: StringName, fact_id: StringName, source: int, truth: bool, tick: int) -> void:
	var r: Read = Read.new()
	r.npc = npc
	r.subject = subject
	r.fact_id = fact_id
	r.source = source
	r.truth = truth
	r.context = context
	r.tick = tick
	reads.append(r)


func on_delivered(npc: StringName, subject: StringName, fact_id: StringName, tick: int) -> void:
	var key: String = _key(npc, subject, fact_id)
	if not _delivered.has(key):
		_delivered[key] = tick


## Violations, one sentence each: a read of another entity's non-public fact that came from a belief with no
## earlier delivery of that fact to that NPC, or any truth-view read of such a fact during a decision or prompt.
func violations(world: NpcfWorld) -> Array[String]:
	var out: Array[String] = []
	for r: Read in reads:
		if r.subject == r.npc:
			continue
		var def: NpcfFactDef = world.state.fact_def(r.fact_id)
		if def == null or def.public:
			continue
		var text: String = "%s/%s" % [r.subject, r.fact_id]
		if r.truth and (r.context == &"decision" or r.context == &"prompt"):
			out.append("%s read %s through the truth view during a %s at tick %d." % [r.npc, text, r.context, r.tick])
			continue
		if r.source == NpcfBelief.Source.DEFAULT or r.source == NpcfBelief.Source.TRUTH:
			continue
		var first: int = _delivered.get(_key(r.npc, r.subject, r.fact_id), -1)
		if first < 0 or first > r.tick:
			out.append("%s read %s from a belief with no earlier delivery of that fact (tick %d)." % [r.npc, text, r.tick])
	return out


static func _key(npc: StringName, subject: StringName, fact_id: StringName) -> String:
	return "%s|%s|%s" % [npc, subject, fact_id]
