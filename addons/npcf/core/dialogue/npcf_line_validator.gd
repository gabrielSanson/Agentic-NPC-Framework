class_name NpcfLineValidator
extends RefCounted
## Checks an LLM reply before it is used (R13.7). The expected reply is one JSON object:
##   {"line": "<text>", "cited_facts": ["f1"], "action": null}
## or, with an action, "action": {"id": "<action id>", "args": {...}}. Every transport is checked the same way.
## Checks run in order and stop at the first failure: parse, schema, banned, citation, action.

const REQUIRED_KEYS: PackedStringArray = ["action", "cited_facts", "line"]


## The JSON schema of that reply shape for one request. Handles and legal actions are enumerated.
static func schema_for(request: NpcfDialogueRequest, max_chars: int) -> Dictionary:
	var handles: Array[String] = []
	for h: StringName in request.handles:
		handles.append(str(h))
	handles.sort()
	var actions: Array[String] = []
	for a: StringName in request.legal_actions:
		actions.append(str(a))
	var handle_items: Dictionary = {"type": "string"}
	if not handles.is_empty():
		handle_items["enum"] = handles
	var action_id: Dictionary = {"type": "string"}
	if not actions.is_empty():
		action_id["enum"] = actions
	var action_object: Dictionary = {
		"type": "object", "required": ["id", "args"], "additionalProperties": false,
		"properties": {"id": action_id, "args": {"type": "object"}},
	}
	return {
		"type": "object",
		"required": ["line", "cited_facts", "action"],
		"additionalProperties": false,
		"properties": {
			"line": {"type": "string", "minLength": 1, "maxLength": max_chars},
			"cited_facts": {"type": "array", "items": handle_items},
			"action": {"anyOf": [{"type": "null"}, action_object]},
		},
	}


## Checks one reply. On success: ok, the stripped text, source llm, the cited handles and the validated action
## (or null). On failure: the category, also listed in validation_failures.
static func check(reply_text: String, request: NpcfDialogueRequest, ctx: NpcfDialogueContext) -> NpcfLineResult:
	var lore: NpcfLoreRules = _lore(ctx)
	var parsed: Variant = JSON.parse_string(reply_text)
	if not (parsed is Dictionary):
		return _fail(&"parse")
	var obj: Dictionary = parsed
	for k: Variant in obj:
		if not (k is String):
			return _fail(&"schema")
		var key_name: String = k
		if not REQUIRED_KEYS.has(key_name):
			return _fail(&"schema")
	for key: String in REQUIRED_KEYS:
		if not obj.has(key):
			return _fail(&"schema")
	var line_v: Variant = obj["line"]
	var cited_v: Variant = obj["cited_facts"]
	var action_v: Variant = obj["action"]
	if not (line_v is String) or not (cited_v is Array):
		return _fail(&"schema")
	var line: String = line_v
	if line.strip_edges() == "" or line.length() > lore.max_line_chars:
		return _fail(&"schema")
	var cited: Array[StringName] = []
	var cited_raw: Array = cited_v
	for c: Variant in cited_raw:
		if not (c is String):
			return _fail(&"schema")
		var cs: String = c
		cited.append(StringName(cs))
	if action_v != null and not (action_v is Dictionary):
		return _fail(&"schema")
	var action_obj: Dictionary = {}
	if action_v is Dictionary:
		action_obj = action_v
		if action_obj.size() != 2 or not (action_obj.get("id") is String) or not (action_obj.get("args") is Dictionary):
			return _fail(&"schema")

	if _banned(line, lore):
		return _fail(&"banned")
	for c: StringName in cited:
		if not request.handles.has(c):
			return _fail(&"citation")

	var action: NpcfActionCall = null
	if action_v is Dictionary:
		var id_text: String = action_obj["id"]
		var id: StringName = StringName(id_text)
		if not request.legal_actions.has(id):
			return _fail(&"action")
		var def: NpcfActionDef = ctx.world.pack.action(id)
		if def == null:
			return _fail(&"action")
		var raw_args: Dictionary = action_obj["args"]
		var args: Dictionary[StringName, Variant] = _coerce(def.args, raw_args)
		if NpcfFieldDef.validate(def.args, args) != "":
			return _fail(&"action")
		action = NpcfActionCall.make(ctx.npc, id, args, 0)

	var result: NpcfLineResult = NpcfLineResult.new()
	result.ok = true
	result.text = line.strip_edges()
	result.source = &"llm"
	result.cited = cited
	result.action = action
	return result


## True when an authored or generated line passes the length and banned-term rules.
static func check_text(text: String, ctx: NpcfDialogueContext) -> bool:
	return text_failure(text, ctx) == &""


## "" when the text passes the length and banned-term rules, else the category (schema or banned).
static func text_failure(text: String, ctx: NpcfDialogueContext) -> StringName:
	var lore: NpcfLoreRules = _lore(ctx)
	var t: String = text.strip_edges()
	if t == "" or t.length() > lore.max_line_chars:
		return &"schema"
	if _banned(t, lore):
		return &"banned"
	return &""


static func _fail(category: StringName) -> NpcfLineResult:
	var r: NpcfLineResult = NpcfLineResult.failed(category)
	r.validation_failures.append(category)
	return r


static func _lore(ctx: NpcfDialogueContext) -> NpcfLoreRules:
	if ctx.dialogue != null and ctx.dialogue.lore != null:
		return ctx.dialogue.lore
	return NpcfLoreRules.new()


static func _banned(text: String, lore: NpcfLoreRules) -> bool:
	var padded: String = NpcfDialogueText.norm(text)
	for term: String in lore.banned_terms:
		if padded.contains(NpcfDialogueText.norm(term)):
			return true
	return false


## Action arguments with their JSON numbers and strings converted to the declared field types.
static func _coerce(fields: Array[NpcfFieldDef], raw: Dictionary) -> Dictionary[StringName, Variant]:
	var out: Dictionary[StringName, Variant] = {}
	for k: Variant in raw:
		var key: StringName = StringName(str(k))
		var value: Variant = raw[k]
		for f: NpcfFieldDef in fields:
			if f != null and f.name == key:
				value = _coerce_value(f.type, value)
		out[key] = value
	return out


static func _coerce_value(t: NpcfFieldDef.FieldType, v: Variant) -> Variant:
	match t:
		NpcfFieldDef.FieldType.STRING_NAME:
			if v is String:
				var s: String = v
				return StringName(s)
		NpcfFieldDef.FieldType.INT:
			if v is float:
				var f: float = v
				if f == floorf(f):
					return int(f)
		NpcfFieldDef.FieldType.FLOAT:
			if v is int:
				var i: int = v
				return float(i)
	return v
