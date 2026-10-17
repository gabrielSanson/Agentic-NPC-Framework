class_name NpcfProviderIntentClassifier
extends NpcfIntentClassifier
## Intent classification through a CHOOSE provider (Kev): one choice question whose options are the intents. Any
## failure (not ready, timeout, busy, down, an unknown option) answers with the fallback classifier (keywords by
## default), so on_done is called exactly once on every path.

var gateway: NpcfProviderGateway
var provider_id: StringName
var fallback: NpcfIntentClassifier = NpcfKeywordIntentClassifier.new()


func _init(p_gateway: NpcfProviderGateway, p_provider_id: StringName) -> void:
	gateway = p_gateway
	provider_id = p_provider_id


func classify(text: String, intents: Array[NpcfIntentDef], ctx: NpcfDialogueContext, on_done: Callable) -> void:
	var kev: NpcfKevAdapter = gateway.adapter(provider_id) as NpcfKevAdapter
	if kev == null or not gateway.is_ready(provider_id) or intents.is_empty():
		fallback.classify(text, intents, ctx, on_done)
		return
	var cfg: NpcfProviderConfig = gateway.config(provider_id)
	var instructions: String = str(cfg.extra.get(&"intent_instructions", "Which option best describes what the player means?"))
	var q: NpcfKevAdapter.Question = NpcfKevAdapter.Question.new()
	q.id = &"intent"
	q.instructions = instructions
	for it: NpcfIntentDef in intents:
		q.options.append(it.id)
		q.descriptions.append(it.description)
	var questions: Array[NpcfKevAdapter.Question] = [q]
	var state: String = 'The player says to %s: "%s"' % [String(ctx.npc), text]
	gateway.send(provider_id, kev.build(cfg, state, questions), _on_result.bind(kev, text, intents, ctx, on_done))


func _on_result(r: NpcfHttpResult, kev: NpcfKevAdapter, text: String, intents: Array[NpcfIntentDef],
		ctx: NpcfDialogueContext, on_done: Callable) -> void:
	var answers: Dictionary[StringName, NpcfKevAdapter.Choice] = kev.parse(r)
	if answers.has(&"intent"):
		var choice: NpcfKevAdapter.Choice = answers[&"intent"]
		if _is_intent(choice.option, intents):
			var confidence: float = clampf(choice.confidence, 0.0, 1.0)
			on_done.call(NpcfIntentResult.make(choice.option, confidence, &"provider"))
			return
	fallback.classify(text, intents, ctx, on_done)


static func _is_intent(option: StringName, intents: Array[NpcfIntentDef]) -> bool:
	for it: NpcfIntentDef in intents:
		if it.id == option:
			return true
	return false
