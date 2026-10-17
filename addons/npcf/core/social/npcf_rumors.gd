class_name NpcfRumors
extends RefCounted
## npcf.share_beliefs (R11.3, R11.4). Moves beliefs, never memory records.

## Speaker -> ticks of its shares inside the current period window.
var _shares: Dictionary[StringName, Array] = {}


## One belief chosen to share, copied out of the speaker's store before any listener is written to.
class Candidate extends RefCounted:
	var subject: StringName = &""
	var fact_id: StringName = &""
	var value: Variant = null
	var confidence: int = 0
	var tick: int = 0
	var event_id: int = -1
	var salience: int = 0
	var tellers: Array[StringName] = []
	var key: int = 0


## Applier handler for SHARE_BELIEFS: share(world, change.subject, listeners, world.clock.tick), where listeners are
## the other NPCs at the speaker's location (world.occupancy.at). Returns "".
func on_change(world: NpcfWorld, change: NpcfStateChange, _cause_event: int) -> String:
	var speaker: StringName = change.subject
	var listeners: Array[StringName] = world.occupancy.at(world.location_of(speaker))
	share(world, speaker, listeners, world.clock.tick)
	return ""


## Shares up to rules.beliefs_per_share beliefs with each listener. Returns the number of beliefs stored
## across all listeners (0 when over the period limit, the speaker is not an NPC, or no listeners).
func share(world: NpcfWorld, speaker: StringName, listeners: Array[StringName], tick: int) -> int:
	var n: NpcfNpcState = world.npc(speaker)
	if n == null:
		return 0
	var rules: NpcfRumorRules = world.pack.rumor_rules
	if not _shares.has(speaker):
		var fresh: Array = []
		_shares[speaker] = fresh
	var times: Array = _shares[speaker]
	var kept: Array = []
	for t: int in times:
		if tick - t < rules.period_ticks:
			kept.append(t)
	times.assign(kept)
	if times.size() >= rules.max_per_period:
		return 0
	times.append(tick)

	var picks: Array[Candidate] = _pick(world, n, speaker, rules.beliefs_per_share)
	if picks.is_empty():
		return 0
	var sorted_listeners: Array[StringName] = listeners.duplicate()
	sorted_listeners.sort_custom(NpcfWorldState.name_less)
	var stored: int = 0
	for listener_id: StringName in sorted_listeners:
		if listener_id == speaker:
			continue
		var listener: NpcfNpcState = world.npc(listener_id)
		if listener == null:
			continue
		for c: Candidate in picks:
			var old: NpcfBelief = listener.beliefs.get_belief(c.subject, c.fact_id)
			if old != null and old.teller == speaker and old.value == c.value:
				continue
			var meta: NpcfBeliefMeta = NpcfBeliefMeta.new()
			meta.source = NpcfBelief.Source.TOLD_BY
			meta.teller = speaker
			var tellers: Array[StringName] = [speaker]
			tellers.append_array(c.tellers)
			meta.tellers = tellers
			meta.tick = c.tick
			meta.event_id = c.event_id
			meta.salience = c.salience
			meta.confidence = clampi(c.confidence + rules.confidence_delta, 0, 100)
			if listener.beliefs.put(NpcfFact.make(c.subject, c.fact_id, c.value), meta):
				stored += 1
	return stored


## The shareable beliefs of the speaker, ordered by salience, then tick (newest first), then a random key drawn
## from the speaker's own stream. Returns the first `count` of them.
func _pick(world: NpcfWorld, n: NpcfNpcState, speaker: StringName, count: int) -> Array[Candidate]:
	var candidates: Array[NpcfBelief] = n.beliefs.shareable(world.pack.facts, 1 << 30)
	var all: Array[Candidate] = []
	var stream: RandomNumberGenerator = world.rng.stream(&"rumor", speaker, &"pick")
	for b: NpcfBelief in candidates:
		var c: Candidate = Candidate.new()
		c.subject = b.subject
		c.fact_id = b.fact_id
		c.value = b.value
		c.confidence = b.confidence
		c.tick = b.tick
		c.event_id = b.event_id
		c.salience = b.salience
		c.tellers = b.tellers.duplicate()
		c.key = stream.randi()
		all.append(c)
	all.sort_custom(_before)
	var out: Array[Candidate] = []
	for i: int in mini(maxi(count, 0), all.size()):
		out.append(all[i])
	return out


static func _before(a: Candidate, b: Candidate) -> bool:
	if a.salience != b.salience:
		return a.salience > b.salience
	if a.tick != b.tick:
		return a.tick > b.tick
	if a.key != b.key:
		return a.key < b.key
	if a.subject != b.subject:
		return String(a.subject) < String(b.subject)
	return String(a.fact_id) < String(b.fact_id)
