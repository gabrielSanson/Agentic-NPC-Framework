class_name NpcfBeliefStore
extends RefCounted
## One NPC's beliefs, keyed by subject and fact (design "5. Beliefs"). Only the delivery service
## and rumors write here, through put().

var _beliefs: Dictionary[String, NpcfBelief] = {}


## Stores a belief when it is newer than the current one, or equally new and more confident.
## Returns true when stored.
func put(fact: NpcfFact, meta: NpcfBeliefMeta) -> bool:
	return put_keyed(key_for(fact.subject, fact.fact_id), fact, meta)


## put() with the key from key_for(), for callers that store one fact at many NPCs and build the key once.
func put_keyed(key: String, fact: NpcfFact, meta: NpcfBeliefMeta) -> bool:
	var b: NpcfBelief = _beliefs.get(key)
	if b != null:
		var newer: bool = meta.tick > b.tick
		var more_sure: bool = meta.tick == b.tick and meta.confidence > b.confidence
		if not newer and not more_sure:
			return false
	else:
		b = NpcfBelief.new()
		_beliefs[key] = b
	# A replaced belief is overwritten in place: readers copy belief values out and keep no reference.
	b.subject = fact.subject
	b.fact_id = fact.fact_id
	b.value = fact.value
	b.confidence = meta.confidence
	b.source = meta.source
	b.teller = meta.teller
	b.tellers.clear()
	for t: StringName in meta.tellers:
		if b.tellers.size() >= NpcfBelief.MAX_TELLERS:
			break
		b.tellers.append(t)
	b.tick = meta.tick
	b.event_id = meta.event_id
	b.salience = meta.salience
	return true


## The belief about a fact, or null when none is held.
func get_belief(subject: StringName, fact_id: StringName) -> NpcfBelief:
	var b: NpcfBelief = _beliefs.get(key_for(subject, fact_id))
	return b


## Every belief, sorted by subject then fact ID.
func all() -> Array[NpcfBelief]:
	var out: Array[NpcfBelief] = []
	for k: String in _beliefs:
		out.append(_beliefs[k])
	out.sort_custom(_by_subject_fact)
	return out


## Shareable beliefs (the fact is declared shareable), newest tick first, ties by subject then fact.
func shareable(defs: Dictionary[StringName, NpcfFactDef], limit: int) -> Array[NpcfBelief]:
	var out: Array[NpcfBelief] = []
	for b: NpcfBelief in all():
		var def: NpcfFactDef = defs.get(b.fact_id)
		if def != null and def.shareable:
			out.append(b)
	out.sort_custom(_newest_first)
	if out.size() > limit:
		out.resize(maxi(0, limit))
	return out


## Lowers the confidence of told and broadcast beliefs by `amount`, floor 0.
func decay(amount: int) -> void:
	for k: String in _beliefs:
		var b: NpcfBelief = _beliefs[k]
		if b.source == NpcfBelief.Source.TOLD_BY or b.source == NpcfBelief.Source.BROADCAST:
			b.confidence = maxi(0, b.confidence - amount)


## Beliefs in live order (all() sorts; this does not), for saves.
func export_live() -> Array[NpcfBelief]:
	var out: Array[NpcfBelief] = []
	for k: String in _beliefs:
		out.append(_beliefs[k])
	return out


## The same beliefs as export_live(), built by one native call. Read-only: callers must not add or remove beliefs.
func live_values() -> Array[NpcfBelief]:
	return _beliefs.values()


## Inserts a saved belief as it is, in saved order (no newer-than check). Used only by restores.
func restore(b: NpcfBelief) -> void:
	_beliefs[key_for(b.subject, b.fact_id)] = b


func size() -> int:
	return _beliefs.size()


## The dictionary key of one subject's belief about one fact.
static func key_for(subject: StringName, fact_id: StringName) -> String:
	return "%s|%s" % [subject, fact_id]


static func _by_subject_fact(a: NpcfBelief, b: NpcfBelief) -> bool:
	if a.subject != b.subject:
		return String(a.subject) < String(b.subject)
	return String(a.fact_id) < String(b.fact_id)


static func _newest_first(a: NpcfBelief, b: NpcfBelief) -> bool:
	if a.tick != b.tick:
		return a.tick > b.tick
	return _by_subject_fact(a, b)
