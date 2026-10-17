class_name NpcfStateChange
extends RefCounted
## One requested change to simulation state. Only NpcfEffectApplier applies these (R5.2).

## Mirrors NpcfEffectDef.Kind without HOOK (hooks expand into these).
enum Kind { SET_FACT, ADD_FACT, NEED_DELTA, TAG_ADD, TAG_REMOVE, REL_DELTA, SHARE_BELIEFS, EMIT_EVENT }

var kind: int = Kind.SET_FACT
var subject: StringName = &""
var fact_id: StringName = &""
var value: Variant = null
var amount: int = 0
var need: StringName = &""
var tag: StringName = &""
var dim: StringName = &""
var other: StringName = &""
var event: NpcfEvent = null


static func set_fact(p_subject: StringName, p_fact_id: StringName, p_value: Variant) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = Kind.SET_FACT
	c.subject = p_subject
	c.fact_id = p_fact_id
	c.value = p_value
	return c


static func add_fact(p_subject: StringName, p_fact_id: StringName, p_amount: int) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = Kind.ADD_FACT
	c.subject = p_subject
	c.fact_id = p_fact_id
	c.amount = p_amount
	return c


static func need_delta(p_npc: StringName, p_need: StringName, p_amount: int) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = Kind.NEED_DELTA
	c.subject = p_npc
	c.need = p_need
	c.amount = p_amount
	return c


static func tag_change(p_npc: StringName, p_tag: StringName, add: bool) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = Kind.TAG_ADD if add else Kind.TAG_REMOVE
	c.subject = p_npc
	c.tag = p_tag
	return c


static func rel_delta(p_subject: StringName, p_other: StringName, p_dim: StringName, p_amount: int) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = Kind.REL_DELTA
	c.subject = p_subject
	c.other = p_other
	c.dim = p_dim
	c.amount = p_amount
	return c


static func emit_event(p_event: NpcfEvent) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = Kind.EMIT_EVENT
	c.event = p_event
	return c


## Save form: the value is tagged (see NpcfSaveCodec); the event, when set, is saved in full.
func to_save() -> Dictionary:
	var ev: Variant = null
	if event != null:
		ev = event.to_save()
	return {
		"kind": kind, "subject": String(subject), "fact_id": String(fact_id),
		"value": NpcfSaveCodec.encode_value(value, "state change value"), "amount": amount,
		"need": String(need), "tag": String(tag), "dim": String(dim), "other": String(other), "event": ev,
	}


## Reads a state change written by to_save.
static func from_save(r: NpcfSaveCodec.Reader, d: Variant, path: String) -> NpcfStateChange:
	var c: NpcfStateChange = NpcfStateChange.new()
	c.kind = r.int_at(d, "kind", path)
	c.subject = r.name_at(d, "subject", path)
	c.fact_id = r.name_at(d, "fact_id", path)
	c.value = r.value_at(d, "value", path)
	c.amount = r.int_at(d, "amount", path)
	c.need = r.name_at(d, "need", path)
	c.tag = r.name_at(d, "tag", path)
	c.dim = r.name_at(d, "dim", path)
	c.other = r.name_at(d, "other", path)
	var ev: Variant = r.get_v(d, "event", path)
	if ev != null:
		c.event = NpcfEvent.from_save(r, ev, path + ".event")
	return c


func describe() -> String:
	return "%s %s %s" % [Kind.keys()[kind], subject, fact_id if fact_id != &"" else (need if need != &"" else tag)]
