class_name NpcfKeywordIntentClassifier
extends NpcfIntentClassifier
## The default classifier: keywords and RegEx patterns (R13.2). Synchronous.

var _patterns: Dictionary[StringName, Array] = {}


func classify(text: String, intents: Array[NpcfIntentDef], _ctx: NpcfDialogueContext, on_done: Callable) -> void:
	var lower: String = text.to_lower()
	var normalized: String = NpcfDialogueText.norm(text)
	var best_id: StringName = &""
	var best_confidence: float = -1.0
	for it: NpcfIntentDef in intents:
		var confidence: float = _confidence(it, lower, normalized)
		# Strictly greater: ties keep the earlier intent in authored order.
		if confidence > best_confidence:
			best_confidence = confidence
			best_id = it.id
	if best_confidence < 0.0:
		on_done.call(NpcfIntentResult.make(&"", 0.0, &"keyword"))
		return
	on_done.call(NpcfIntentResult.make(best_id, best_confidence, &"keyword"))


func _confidence(it: NpcfIntentDef, lower: String, normalized: String) -> float:
	for re: RegEx in _regexes(it):
		if re.search(lower) != null:
			return 1.0
	if it.keywords.is_empty():
		return 0.0
	var hits: int = 0
	for k: String in it.keywords:
		if normalized.contains(NpcfDialogueText.norm(k)):
			hits += 1
	return minf(1.0, float(hits) / float(mini(3, it.keywords.size())))


## The compiled patterns of an intent, cached by intent ID. Patterns were checked when the pack loaded.
func _regexes(it: NpcfIntentDef) -> Array:
	var cached: Array = _patterns.get(it.id, [])
	if not _patterns.has(it.id):
		for p: String in it.patterns:
			var re: RegEx = RegEx.new()
			if re.compile(p) == OK:
				cached.append(re)
		_patterns[it.id] = cached
	return cached
