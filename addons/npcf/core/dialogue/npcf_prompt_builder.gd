class_name NpcfPromptBuilder
extends RefCounted
## Builds the LLM request for one NPC turn (R13.5). Every macro value comes from the NPC's own view, its memory log,
## the rule outcome and the legal dialogue actions, never from ground truth.


## The request, or null when no template applies (none for the archetype and no default template).
static func build(ctx: NpcfDialogueContext) -> NpcfDialogueRequest:
	var world: NpcfWorld = ctx.world
	var dialogue: NpcfDialogueDef = ctx.dialogue
	var template: NpcfPromptTemplate = dialogue.templates.get(_archetype(world, ctx.npc))
	if template == null:
		template = dialogue.default_template
	if template == null:
		return null
	var request: NpcfDialogueRequest = NpcfDialogueRequest.new()
	request.npc = ctx.npc

	var memories: String = _memories(ctx, request)
	var facts: String = _facts(ctx, request)
	var actions: String = _actions(ctx, request)
	var values: Dictionary[StringName, String] = {}
	for m: NpcfPromptMacro in template.macros:
		if m != null:
			values[m.name] = _macro_value(m, ctx, memories, facts, actions)

	var variant: NpcfPromptVariant = _variant(template, ctx)
	var situation: String = ""
	if variant != null:
		request.variant = variant.id
		situation = _fill(variant.text, values)
	values[&"situation"] = situation

	var user: String = _fill(template.scenario_text, values) + "\n\nThe player says: " + ctx.player_text \
			+ "\nRule outcome you must respect: " + str(ctx.outcome.result)
	var messages: Array[NpcfChatMessage] = []
	messages.append(NpcfChatMessage.make(&"system", _fill(template.system_text, values)))
	messages.append(NpcfChatMessage.make(&"user", user))
	request.messages = messages

	var llm: NpcfLlmConfig = dialogue.llm if dialogue.llm != null else NpcfLlmConfig.new()
	request.temperature = llm.temperature
	request.max_tokens = llm.max_tokens
	request.structured_output = llm.structured_output
	var lore: NpcfLoreRules = dialogue.lore if dialogue.lore != null else NpcfLoreRules.new()
	request.schema = NpcfLineValidator.schema_for(request, lore.max_line_chars)
	return request


static func _archetype(world: NpcfWorld, npc: StringName) -> StringName:
	var n: NpcfNpcState = world.npc(npc)
	return n.resolved.archetype if n != null and n.resolved != null else &""


## The first variant whose condition holds, or null.
static func _variant(t: NpcfPromptTemplate, ctx: NpcfDialogueContext) -> NpcfPromptVariant:
	var no_args: Dictionary[StringName, Variant] = {}
	for v: NpcfPromptVariant in t.variants:
		if v != null and (v.condition == null or NpcfConditions.check(ctx.world, ctx.view, v.condition, no_args, false)):
			return v
	return null


static func _fill(text: String, values: Dictionary[StringName, String]) -> String:
	var out: String = text
	for k: StringName in values:
		out = out.replace("{{%s}}" % k, values[k])
	return out


static func _macro_value(m: NpcfPromptMacro, ctx: NpcfDialogueContext, memories: String, facts: String, actions: String) -> String:
	var world: NpcfWorld = ctx.world
	var view: NpcfNpcView = ctx.view
	match m.source:
		NpcfPromptMacro.Source.NPC_NAME:
			return view.display_name()
		NpcfPromptMacro.Source.PERSONA:
			return view.persona()
		NpcfPromptMacro.Source.LOCATION_NAME:
			return _location_name(world, world.location_of(ctx.npc))
		NpcfPromptMacro.Source.TIME_OF_DAY:
			var minute: int = view.minute_of_day()
			return "%02d:%02d" % [minute / 60, minute % 60]
		NpcfPromptMacro.Source.NEED_BAND:
			if m.need == null:
				return "unknown"
			var v: float = view.need_normalized(m.need.id)
			if v < 1.0 / 3.0:
				return "low"
			return "medium" if v < 2.0 / 3.0 else "high"
		NpcfPromptMacro.Source.FACT:
			if m.fact == null:
				return "unknown"
			var read: NpcfFactRead = view.fact(_subject(m.subject_from, ctx), m.fact.id)
			return str(read.value) if read.confidence > 0 else "unknown"
		NpcfPromptMacro.Source.RELATIONSHIP_BAND:
			if m.dim == null:
				return "neutral"
			var band: StringName = view.relationship_band(ctx.player, m.dim.id)
			return str(band) if band != &"" else "neutral"
		NpcfPromptMacro.Source.RULE_OUTCOME:
			return str(ctx.outcome.result)
		NpcfPromptMacro.Source.MEMORIES:
			return memories
		NpcfPromptMacro.Source.FACTS:
			return facts
		NpcfPromptMacro.Source.ACTIONS:
			return actions
	return ""


static func _subject(from: NpcfPromptMacro.SubjectFrom, ctx: NpcfDialogueContext) -> StringName:
	match from:
		NpcfPromptMacro.SubjectFrom.PLAYER:
			return ctx.player
		NpcfPromptMacro.SubjectFrom.LOCATION:
			return ctx.world.location_of(ctx.npc)
	return ctx.npc


static func _location_name(world: NpcfWorld, location: StringName) -> String:
	var def: NpcfLocationDef = world.pack.locations.get(location)
	return def.display_name if def != null and def.display_name != "" else str(location)


## The NPC's remembered episodes that best match the player (R7.3), rendered from the pack's memory texts.
static func _memories(ctx: NpcfDialogueContext, request: NpcfDialogueRequest) -> String:
	var world: NpcfWorld = ctx.world
	var npc: NpcfNpcState = world.npc(ctx.npc)
	var subjects: Array[StringName] = [ctx.player]
	var top: Array[NpcfMemoryRecord] = NpcfMemoryRetrieval.top(npc.memory, subjects, world.clock.tick, world.sim.retrieval_k, world.sim)
	var parts: PackedStringArray = []
	for r: NpcfMemoryRecord in top:
		request.memory_ids.append(r.id)
		parts.append(_memory_text(world, r))
	return "; ".join(parts) if not parts.is_empty() else "none"


static func _memory_text(world: NpcfWorld, r: NpcfMemoryRecord) -> String:
	var where: String = _location_name(world, r.location)
	var template: String = world.pack.dialogue.memory_texts.get(r.message_key, "")
	if template == "":
		return "%s at %s" % [str(r.kind), where]
	var names: PackedStringArray = []
	for s: StringName in r.subjects:
		names.append(_display(world, s))
	var out: String = template.replace("{actors}", ", ".join(names)).replace("{targets}", ", ".join(names))
	out = out.replace("{location}", where)
	for key: StringName in r.params:
		out = out.replace("{%s}" % key, str(r.params[key]))
	return out


## An NPC's view name; any other entity keeps its ID.
static func _display(world: NpcfWorld, entity: StringName) -> String:
	var n: NpcfNpcState = world.npc(entity)
	return str(entity) if n == null or n.resolved == null or n.resolved.display_name == "" else n.resolved.display_name


## The facts the reply may cite: the rule outcome's revealed facts first, then the NPC's beliefs by confidence.
## Each gets a handle f1, f2 ... and one line in the prompt.
static func _facts(ctx: NpcfDialogueContext, request: NpcfDialogueRequest) -> String:
	var world: NpcfWorld = ctx.world
	var cap: int = ctx.dialogue.max_prompt_facts
	var seen: Dictionary[String, bool] = {}
	var entries: Array[NpcfFactRef] = []
	var values: Array = []
	for f: NpcfFactRef in ctx.outcome.revealed:
		var key: String = "%s/%s" % [f.subject, f.fact_id]
		if not seen.has(key):
			seen[key] = true
			entries.append(f)
			values.append(ctx.view.fact(f.subject, f.fact_id).value)
	var beliefs: Array[NpcfBelief] = world.npc(ctx.npc).beliefs.all()
	beliefs.sort_custom(_more_confident)
	for b: NpcfBelief in beliefs:
		if b.confidence <= 0:
			continue
		var key: String = "%s/%s" % [b.subject, b.fact_id]
		if seen.has(key):
			continue
		seen[key] = true
		entries.append(NpcfFactRef.make(b.subject, b.fact_id))
		values.append(b.value)
	var lines: PackedStringArray = []
	for i: int in mini(cap, entries.size()):
		var f: NpcfFactRef = entries[i]
		var handle: StringName = StringName("f%d" % (i + 1))
		request.handles[handle] = NpcfFactRef.make(f.subject, f.fact_id, handle)
		request.injected_facts.append("%s=%s/%s" % [handle, f.subject, f.fact_id])
		lines.append("%s: %s %s = %s" % [handle, f.subject, f.fact_id, str(values[i])])
	return "\n".join(lines) if not lines.is_empty() else "none"


static func _more_confident(a: NpcfBelief, b: NpcfBelief) -> bool:
	if a.confidence != b.confidence:
		return a.confidence > b.confidence
	if a.subject != b.subject:
		return String(a.subject) < String(b.subject)
	return String(a.fact_id) < String(b.fact_id)


## The dialogue-tier actions the reply may name, as "id(arg: type, ...)".
static func _actions(ctx: NpcfDialogueContext, request: NpcfDialogueRequest) -> String:
	var legal: NpcfLegalActions = NpcfDialogueService.legal_dialogue_actions(ctx.world, ctx.view)
	var parts: PackedStringArray = []
	for a: NpcfActionDef in legal.actions:
		request.legal_actions.append(a.id)
		var args: PackedStringArray = []
		for f: NpcfFieldDef in a.args:
			args.append("%s: %s" % [f.name, str(NpcfFieldDef.FieldType.keys()[f.type]).to_lower()])
		parts.append("%s(%s)" % [a.id, ", ".join(args)])
	return ", ".join(parts) if not parts.is_empty() else "none"
