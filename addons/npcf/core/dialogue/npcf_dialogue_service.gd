class_name NpcfDialogueService
extends RefCounted
## The dialogue pipeline (R13). A turn runs between ticks on committed state: addressee, intent, rule outcome
## (queued as an npcf.conversation event for the next tick), authored line (held), presentation, then the line
## generator. Exactly one `line` signal per started turn. Player text never reaches decisions or state: only the
## intent ID, the rule outcome and validated dialogue-tier actions do.

signal line(npc: StringName, text: String, line_id: int, source: StringName, presentation: Dictionary)
signal no_addressee(reason: StringName)

const RECORD_CAP: int = 64

var classifier: NpcfIntentClassifier = NpcfKeywordIntentClassifier.new()
var chooser: NpcfPresentationChooser = NpcfPresentationChooser.new()
var generator: NpcfLineGenerator = NpcfLineGenerator.new()
## Most recent turn records, oldest first, capped at RECORD_CAP.
var records: Array[NpcfDialogueTurnRecord] = []

var _next_line_id: int = 1
## NPC -> line ID of its unfinished turn.
var _pending: Dictionary[StringName, int] = {}
var _last_addressee: StringName = &""
var _last_talk_tick: int = -1
var _disposed: bool = false


## Starts a turn for `text`. Returns its line ID, or -1 after emitting no_addressee.
func begin_turn(world: NpcfWorld, text: String, npc: StringName = &"") -> int:
	if world.pack.dialogue == null:
		no_addressee.emit(&"no_dialogue")
		return -1
	var player: StringName = world.sim.player_entity
	if player == &"":
		no_addressee.emit(&"no_player")
		return -1
	var picked: Array[StringName] = pick_addressee(world, npc)
	var addressee: StringName = picked[0]
	if addressee == &"":
		no_addressee.emit(picked[1])
		return -1
	if _pending.has(addressee):
		no_addressee.emit(&"busy")
		return -1

	var line_id: int = _next_line_id
	_next_line_id += 1
	_pending[addressee] = line_id
	_last_addressee = addressee
	_last_talk_tick = world.clock.tick

	var ctx: NpcfDialogueContext = NpcfDialogueContext.new()
	ctx.world = world
	ctx.npc = addressee
	ctx.player = player
	ctx.player_text = text
	ctx.view = world.view(addressee)
	ctx.dialogue = world.pack.dialogue
	ctx.line_id = line_id
	var rec: NpcfDialogueTurnRecord = NpcfDialogueTurnRecord.new()
	rec.line_id = line_id
	rec.tick = world.clock.tick
	rec.npc = addressee
	rec.addressee_reason = picked[1]
	classifier.classify(text, world.pack.dialogue.intents, ctx, _on_classified.bind(world, ctx, rec))
	return line_id


## Ignores every callback that arrives later (a provider replying after the world is gone).
## The next line ID, for saves.
func export_next_line_id() -> int:
	return _next_line_id


## The last addressee, for saves.
func export_last_addressee() -> StringName:
	return _last_addressee


## The tick of the last talk, for saves.
func export_last_talk_tick() -> int:
	return _last_talk_tick


## Restores the conversation counters. Turn records and turns in flight are not saved and start empty.
func restore_state(next_line_id: int, last_addressee: StringName, last_talk_tick: int) -> void:
	_next_line_id = next_line_id
	_last_addressee = last_addressee
	_last_talk_tick = last_talk_tick
	records.clear()
	_pending.clear()


func dispose() -> void:
	_disposed = true
	_pending.clear()


## The addressee and the reason, or [&"", reason] when nobody is addressed. Pure; tests call it.
func pick_addressee(world: NpcfWorld, npc: StringName) -> Array[StringName]:
	var player: StringName = world.sim.player_entity
	if npc != &"":
		if world.npc(npc) != null:
			return _pair(npc, &"named")
		return _pair(&"", &"unknown_npc")
	var perception: NpcfPerceptionAdapter = world.adapters.perception
	var candidates: Array[StringName] = perception.audible_npcs(player, world.world_view())
	if candidates.is_empty():
		return _pair(&"", &"none_in_range")
	var facing: StringName = perception.facing_npc(player, world.world_view())
	if facing != &"" and candidates.has(facing):
		return _pair(facing, &"facing")
	var window: int = world.pack.dialogue.last_talk_window_ticks
	if _last_addressee != &"" and candidates.has(_last_addressee) and _last_talk_tick >= 0 \
			and world.clock.tick - _last_talk_tick <= window:
		return _pair(_last_addressee, &"last_talked")
	if candidates.size() == 1:
		return _pair(candidates[0], &"only_candidate")
	return _pair(&"", &"ambiguous")


## The authored line for (intent, result, band), placeholders filled. Draws from the NPC's dialogue line stream.
func authored_line(world: NpcfWorld, npc: StringName, intent: StringName, result: StringName, band: StringName) -> String:
	var dialogue: NpcfDialogueDef = world.pack.dialogue
	var chosen: NpcfDialogueLineSet = null
	for ls: NpcfDialogueLineSet in dialogue.lines:
		if ls.intent != null and ls.intent.id == intent and ls.result == result and band != &"" and ls.band == band:
			chosen = ls
			break
	if chosen == null:
		for ls: NpcfDialogueLineSet in dialogue.lines:
			if ls.intent != null and ls.intent.id == intent and ls.result == result and ls.band == &"":
				chosen = ls
				break
	var lines: PackedStringArray = chosen.lines if chosen != null else dialogue.default_lines
	var rng: RandomNumberGenerator = world.rng.stream(&"dialogue", npc, &"line")
	var index: int = rng.randi_range(0, lines.size() - 1)
	return fill_line_placeholders(world, npc, lines[index], result)


## Fills {npc_name} {location_name} {time_of_day} {result} in an authored line. Pure.
static func fill_line_placeholders(world: NpcfWorld, npc: StringName, text: String, result: StringName) -> String:
	var view: NpcfNpcView = world.view(npc)
	var at: StringName = world.location_of(npc)
	var location_name: String = String(at)
	var loc: NpcfLocationDef = world.pack.locations.get(at)
	if loc != null and loc.display_name != "":
		location_name = loc.display_name
	var minute: int = view.minute_of_day()
	var time_of_day: String = "%02d:%02d" % [minute / 60, minute % 60]
	return text.replace("{npc_name}", view.display_name()).replace("{location_name}", location_name) \
			.replace("{time_of_day}", time_of_day).replace("{result}", String(result))


## The rule outcome: the intent's hook first, else its declarative outcome, else none. Keeps only changes the
## addressed NPC may make and reveals it can hold. Records the reveals in `rec`.
func compute_outcome(world: NpcfWorld, npc: StringName, intent: NpcfIntentDef, rec: NpcfDialogueTurnRecord) -> NpcfRuleOutcome:
	var player: StringName = world.sim.player_entity
	var outcome: NpcfRuleOutcome = null
	if intent.hook != null:
		outcome = world.hooks.intent(intent.hook, world.view(npc), intent.id, player)
	if outcome == null and intent.outcome != null:
		outcome = _declared(world, npc, intent.outcome)
	if outcome == null:
		outcome = NpcfRuleOutcome.none()

	var kept_changes: Array[NpcfStateChange] = []
	for c: NpcfStateChange in outcome.changes:
		if not _change_allowed(c, npc):
			push_warning("npcf: dialogue outcome change dropped (not allowed for %s): %s" % [npc, c.describe()])
		elif world.applier.validate(world, c) != "":
			push_warning("npcf: dialogue outcome change dropped: %s" % world.applier.validate(world, c))
		else:
			kept_changes.append(c)
	outcome.changes = kept_changes

	var view: NpcfNpcView = world.view(npc)
	var kept_reveals: Array[NpcfFactRef] = []
	for f: NpcfFactRef in outcome.revealed:
		var key: String = "%s/%s" % [f.subject, f.fact_id]
		var def: NpcfFactDef = world.state.fact_def(f.fact_id)
		var holds: bool = f.subject == npc or (def != null and def.public) or view.fact(f.subject, f.fact_id).confidence > 0
		if def != null and def.shareable and holds:
			kept_reveals.append(f)
			rec.revealed.append(key)
		else:
			rec.dropped_reveals.append(key)
	outcome.revealed = kept_reveals
	return outcome


func _on_classified(result: NpcfIntentResult, world: NpcfWorld, ctx: NpcfDialogueContext, rec: NpcfDialogueTurnRecord) -> void:
	if _disposed:
		return
	var dialogue: NpcfDialogueDef = ctx.dialogue
	var confidence: float = result.confidence
	var intent: NpcfIntentDef = world.pack.intents.get(result.intent)
	if intent == null:
		confidence = 0.0
	if intent == null or confidence < dialogue.confidence_threshold:
		intent = dialogue.fallback_intent
		rec.fell_back = true
	rec.intent = intent.id
	rec.confidence = confidence
	rec.classifier_source = result.source
	ctx.intent = intent.id
	ctx.confidence = confidence

	# The intent's outcome decides what the NPC reveals, so its fact reads are audited as a decision (C5c).
	if world.audit != null:
		world.audit.begin(&"decision")
	var outcome: NpcfRuleOutcome = compute_outcome(world, ctx.npc, intent, rec)
	if world.audit != null:
		world.audit.end()
	ctx.outcome = outcome
	rec.result = outcome.result
	var facts: Array[String] = []
	for f: NpcfFactRef in outcome.revealed:
		facts.append("%s/%s" % [f.subject, f.fact_id])
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = NpcfFramework.CONVERSATION
	e.actors.append(ctx.player)
	e.targets.append(ctx.npc)
	e.location = world.location_of(ctx.npc)
	e.payload[&"intent"] = intent.id
	e.payload[&"result"] = outcome.result
	if not facts.is_empty():
		e.payload[&"facts"] = facts
	world.queue_input(NpcfInput.conversation(e, outcome.changes))

	var band: StringName = &""
	if dialogue.band_dim != null:
		band = ctx.view.relationship_band(ctx.player, dialogue.band_dim.id)
	ctx.band = band
	ctx.authored_line = authored_line(world, ctx.npc, intent.id, outcome.result, band)
	chooser.choose(dialogue.presentation, ctx, _on_presented.bind(world, ctx, rec))


func _on_presented(answers: Dictionary, world: NpcfWorld, ctx: NpcfDialogueContext, rec: NpcfDialogueTurnRecord) -> void:
	if _disposed:
		return
	var presentation: Dictionary[StringName, StringName] = {}
	for q: NpcfPresentationQuestionDef in ctx.dialogue.presentation:
		presentation[q.id] = _answer_for(q, answers, ctx)
	ctx.presentation = presentation
	rec.presentation = presentation.duplicate()
	var legal: NpcfLegalActions = legal_dialogue_actions(world, ctx.view)
	for a: NpcfActionDef in legal.actions:
		rec.offered_actions.append(a.id)
	generator.generate(ctx, _on_generated.bind(world, ctx, rec))


func _on_generated(r: NpcfLineResult, world: NpcfWorld, ctx: NpcfDialogueContext, rec: NpcfDialogueTurnRecord) -> void:
	if _disposed:
		return
	var req: NpcfDialogueRequest = ctx.last_request
	if req != null:
		rec.variant = req.variant
		rec.injected_facts = req.injected_facts.duplicate()
		rec.injected_memories = req.memory_ids.duplicate()
	var text: String = ctx.authored_line
	var source: StringName = &"authored"
	rec.latency_ms = r.latency_ms
	if not r.ok and r.failure == &"off":
		rec.llm_status = &"off"
	elif r.ok and NpcfLineValidator.text_failure(r.text, ctx) == &"":
		rec.llm_status = &"ok"
		text = r.text.strip_edges()
		source = r.source if r.source != &"" else &"llm"
		if r.action != null:
			r.action.npc = ctx.npc
			world.queue_input(NpcfInput.start_action(r.action))
			rec.action = r.action.action
	else:
		rec.llm_status = &"failed"
		rec.failure = r.failure if not r.ok else NpcfLineValidator.text_failure(r.text, ctx)
		rec.validation_failures = r.validation_failures.duplicate()
	rec.line_source = source
	records.append(rec)
	if records.size() > RECORD_CAP:
		records.remove_at(0)
	_pending.erase(ctx.npc)
	line.emit(ctx.npc, text, ctx.line_id, source, ctx.presentation)


## The dialogue-tier actions an NPC may start right now, in ID order.
static func legal_dialogue_actions(world: NpcfWorld, view: NpcfNpcView) -> NpcfLegalActions:
	var ids: Array[StringName] = []
	ids.assign(world.pack.actions.keys())
	ids.sort_custom(NpcfWorldState.name_less)
	var candidates: Array[NpcfActionDef] = []
	for id: StringName in ids:
		var a: NpcfActionDef = world.pack.actions[id]
		if a.tier == NpcfActionDef.Tier.DIALOGUE:
			candidates.append(a)
	return world.action_registry.legal_for(world, view, candidates, NpcfActionDef.Tier.DIALOGUE)


## The answer for one question: the reply's answer when it is an option, else the rule answer.
func _answer_for(q: NpcfPresentationQuestionDef, answers: Dictionary, ctx: NpcfDialogueContext) -> StringName:
	var raw: Variant = answers.get(q.id, &"")
	if typeof(raw) == TYPE_STRING_NAME:
		var answer: StringName = raw
		if q.options.has(answer):
			return answer
	return NpcfPresentationChooser.rule_answer(q, ctx)


func _declared(world: NpcfWorld, npc: StringName, def: NpcfOutcomeDef) -> NpcfRuleOutcome:
	var o: NpcfRuleOutcome = NpcfRuleOutcome.new()
	o.result = def.result
	var player: StringName = world.sim.player_entity
	var dims: Array[StringName] = []
	dims.assign(def.rel_deltas.keys())
	dims.sort_custom(NpcfWorldState.name_less)
	for dim: StringName in dims:
		o.changes.append(NpcfStateChange.rel_delta(npc, player, dim, def.rel_deltas[dim]))
	for fact: NpcfFactDef in def.reveal:
		var subject: StringName = npc
		if def.reveal_subject == NpcfOutcomeDef.RevealSubject.PLAYER:
			subject = player
		elif def.reveal_subject == NpcfOutcomeDef.RevealSubject.LOCATION:
			subject = world.location_of(npc)
		o.revealed.append(NpcfFactRef.make(subject, fact.id))
	return o


static func _change_allowed(c: NpcfStateChange, npc: StringName) -> bool:
	match c.kind:
		NpcfStateChange.Kind.REL_DELTA, NpcfStateChange.Kind.TAG_ADD, NpcfStateChange.Kind.TAG_REMOVE, \
		NpcfStateChange.Kind.SET_FACT, NpcfStateChange.Kind.ADD_FACT:
			return c.subject == npc
	return false


static func _pair(a: StringName, b: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	out.append(a)
	out.append(b)
	return out
