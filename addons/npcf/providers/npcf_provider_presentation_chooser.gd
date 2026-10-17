class_name NpcfProviderPresentationChooser
extends NpcfPresentationChooser
## Presentation answers through a CHOOSE provider (Kev): one choice question per presentation question. An option
## the provider names that is not one of the question's options, and any failed request, gets the rule answer
## (the same answer the base class gives). A newer turn replaces a waiting older one (replace key "presentation").

var gateway: NpcfProviderGateway
var provider_id: StringName


func _init(p_gateway: NpcfProviderGateway, p_provider_id: StringName) -> void:
	gateway = p_gateway
	provider_id = p_provider_id


func choose(questions: Array[NpcfPresentationQuestionDef], ctx: NpcfDialogueContext, on_done: Callable) -> void:
	var kev: NpcfKevAdapter = gateway.adapter(provider_id) as NpcfKevAdapter
	if kev == null or not gateway.is_ready(provider_id) or questions.is_empty():
		super.choose(questions, ctx, on_done)
		return
	var kq: Array[NpcfKevAdapter.Question] = []
	for q: NpcfPresentationQuestionDef in questions:
		var k: NpcfKevAdapter.Question = NpcfKevAdapter.Question.new()
		k.id = q.id
		k.instructions = q.description
		for o: StringName in q.options:
			var description: String = q.option_descriptions.get(o, "")
			k.options.append(o)
			k.descriptions.append(description)
		kq.append(k)
	var outcome_text: String = "none" if ctx.outcome == null else String(ctx.outcome.result)
	var band_text: String = "unknown" if ctx.band == &"" else String(ctx.band)
	var state: String = '%s answers the player. The player said: "%s". Intent: %s. Result: %s. Relationship: %s.' % [
		String(ctx.npc), ctx.player_text, String(ctx.intent), outcome_text, band_text]
	var cfg: NpcfProviderConfig = gateway.config(provider_id)
	gateway.send(provider_id, kev.build(cfg, state, kq), _on_result.bind(kev, questions, ctx, on_done),
			Callable(), &"presentation")


func _on_result(r: NpcfHttpResult, kev: NpcfKevAdapter, questions: Array[NpcfPresentationQuestionDef],
		ctx: NpcfDialogueContext, on_done: Callable) -> void:
	var answers: Dictionary[StringName, NpcfKevAdapter.Choice] = kev.parse(r)
	var out: Dictionary[StringName, StringName] = {}
	for q: NpcfPresentationQuestionDef in questions:
		var picked: StringName = rule_answer(q, ctx)
		if answers.has(q.id):
			var choice: NpcfKevAdapter.Choice = answers[q.id]
			if q.options.has(choice.option):
				picked = choice.option
		out[q.id] = picked
	on_done.call(out)
