class_name NpcfBeliefMapper
extends RefCounted
## Maps a delivered event to the facts one receiver comes to believe (design "5. Beliefs"). Framework
## kinds have fixed mappings. A pack kind uses its mapper hook when set, otherwise its declarative
## fact templates. Anything that cannot be mapped gives no belief.


static func map(world: NpcfWorld, e: NpcfEvent, receiver: StringName) -> Array[NpcfFact]:
	var out: Array[NpcfFact] = []
	if e.kind == NpcfFramework.FACT_CHANGED or e.kind == NpcfFramework.EXPECTATION_FAILED:
		return _payload_fact(e)
	if e.kind == NpcfFramework.ARRIVED or e.kind == NpcfFramework.DEPARTED:
		if e.actors.is_empty():
			return out
		var where: StringName = e.location if e.kind == NpcfFramework.ARRIVED else &""
		out.append(NpcfFact.make(e.actors[0], NpcfFramework.AT, where))
		return out
	if e.kind == NpcfFramework.TAGS_CHANGED or e.kind == NpcfFramework.NEED_THRESHOLD or e.kind == NpcfFramework.CONVERSATION:
		return out
	var def: NpcfEventKindDef = world.pack.event_kind(e.kind)
	if def == null:
		return out
	if def.mapper != null:
		return world.hooks.mapper(def.mapper, NpcfEventView.new(e), receiver)
	for t: NpcfFactTemplate in def.beliefs:
		var f: NpcfFact = _template(world, e, t)
		if f != null:
			out.append(f)
	return out


## The fact carried by a fact_changed or expectation_failed payload (subject, fact, value).
static func _payload_fact(e: NpcfEvent) -> Array[NpcfFact]:
	var out: Array[NpcfFact] = []
	var subject: Variant = e.payload.get(&"subject", &"")
	var fact_id: Variant = e.payload.get(&"fact", &"")
	if typeof(subject) != TYPE_STRING_NAME or typeof(fact_id) != TYPE_STRING_NAME:
		return out
	var s: StringName = subject
	var f: StringName = fact_id
	out.append(NpcfFact.make(s, f, e.payload.get(&"value", null)))
	return out


## One declarative template. Null when its subject or value cannot be read from this event.
static func _template(world: NpcfWorld, e: NpcfEvent, t: NpcfFactTemplate) -> NpcfFact:
	if t == null or t.fact == null:
		return null
	var subject: StringName = &""
	match t.subject_from:
		NpcfFactTemplate.SubjectFrom.ACTOR_0:
			if e.actors.is_empty():
				return null
			subject = e.actors[0]
		NpcfFactTemplate.SubjectFrom.TARGET_0:
			if e.targets.is_empty():
				return null
			subject = e.targets[0]
		NpcfFactTemplate.SubjectFrom.LOCATION:
			subject = e.location
		NpcfFactTemplate.SubjectFrom.GLOBAL:
			subject = NpcfFramework.GLOBAL
		NpcfFactTemplate.SubjectFrom.PAYLOAD:
			var raw_subject: Variant = e.payload.get(t.subject_field, &"")
			if typeof(raw_subject) != TYPE_STRING_NAME:
				return null
			subject = raw_subject
	var value: Variant = null
	match t.value_from:
		NpcfFactTemplate.ValueFrom.LITERAL:
			value = t.value_literal
		NpcfFactTemplate.ValueFrom.PAYLOAD:
			value = e.payload.get(t.value_field, null)
		NpcfFactTemplate.ValueFrom.ACTOR_0:
			if e.actors.is_empty():
				return null
			value = e.actors[0]
		NpcfFactTemplate.ValueFrom.TARGET_0:
			if e.targets.is_empty():
				return null
			value = e.targets[0]
		NpcfFactTemplate.ValueFrom.LOCATION:
			value = e.location
	if t.fact.value_type == NpcfFactDef.ValueType.FLOAT and typeof(value) == TYPE_INT:
		var as_int: int = value
		var as_float: float = float(as_int)
		value = as_float
	if not t.fact.accepts(value):
		return null
	return NpcfFact.make(subject, t.fact.id, value)
