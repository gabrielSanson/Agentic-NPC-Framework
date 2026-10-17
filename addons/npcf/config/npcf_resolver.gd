class_name NpcfResolver
extends RefCounted
## Merges the four configuration layers into an NpcfResolvedCharacter (R4.1):
## archetype -> personalities in order -> character -> scenario cast entry.
## References replace when non-null. Dictionaries merge by key, later wins, except multiplier
## dictionaries, which multiply per key. Tags and goals append and de-duplicate. Voice strings
## concatenate with a space.


static func resolve(cast: NpcfCastEntry) -> NpcfResolvedCharacter:
	var ch: NpcfCharacterDef = cast.character
	var r: NpcfResolvedCharacter = NpcfResolvedCharacter.new()
	r.id = ch.id
	r.display_name = ch.display_name if ch.display_name != "" else String(ch.id)
	var arch: NpcfArchetypeDef = ch.archetype
	if arch != null:
		r.archetype = arch.id
		_append_unique(r.tags, arch.tags)
		r.needs = arch.needs.duplicate()
		for n: NpcfNeedDef in arch.needs:
			if n != null:
				r.need_start[n.id] = n.start
		for g: NpcfGoalDef in arch.goals:
			_append_goal(r.goals, g)
		r.planner = arch.planner
		r.schedule = arch.schedule
		r.decision_period_ticks = maxi(1, arch.decision_period_ticks)
		r.rel_defaults = arch.rel_defaults.duplicate()
	var voices: PackedStringArray = []
	var speech: PackedStringArray = []
	for p: NpcfPersonalityDef in ch.personalities:
		if p == null:
			continue
		r.personalities.append(p.id)
		_multiply(r.goal_multipliers, p.goal_multipliers)
		_multiply(r.action_multipliers, p.action_multipliers)
		_append_unique(r.tags, p.tags_add)
		if p.voice.strip_edges() != "":
			voices.append(p.voice.strip_edges())
		if p.speech_instruction.strip_edges() != "":
			speech.append(p.speech_instruction.strip_edges())
	_merge(r.need_start, ch.need_start)
	_multiply(r.goal_multipliers, ch.goal_multipliers)
	_append_unique(r.tags, ch.tags_add)
	for g: NpcfGoalDef in ch.extra_goals:
		_append_goal(r.goals, g)
	if ch.schedule != null:
		r.schedule = ch.schedule
	if ch.planner != null:
		r.planner = ch.planner
	if ch.voice.strip_edges() != "":
		voices.append(ch.voice.strip_edges())
	if ch.speech_instruction.strip_edges() != "":
		speech.append(ch.speech_instruction.strip_edges())
	r.voice = " ".join(voices)
	r.speech_instruction = " ".join(speech)
	r.speech_voice_id = ch.speech_voice_id.strip_edges()
	_merge(r.need_start, cast.need_start)
	_append_unique(r.tags, cast.tags_add)
	if cast.schedule != null:
		r.schedule = cast.schedule
	r.start_location = cast.start_location.id if cast.start_location != null else &""
	return r


static func _append_unique(into: Array[StringName], items: Array[StringName]) -> void:
	for t: StringName in items:
		if not into.has(t):
			into.append(t)


static func _append_goal(into: Array[NpcfGoalDef], g: NpcfGoalDef) -> void:
	if g == null:
		return
	for existing: NpcfGoalDef in into:
		if existing.id == g.id:
			return
	into.append(g)


static func _merge(into: Dictionary[StringName, int], layer: Dictionary[StringName, int]) -> void:
	for k: StringName in layer:
		into[k] = layer[k]


static func _multiply(into: Dictionary[StringName, float], layer: Dictionary[StringName, float]) -> void:
	for k: StringName in layer:
		into[k] = into.get(k, 1.0) * layer[k]
