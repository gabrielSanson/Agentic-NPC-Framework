class_name NpcfPresentationChooser
extends RefCounted
## Answers the pack's presentation questions for one line. The base class is the rule-based default. on_done
## receives a Dictionary[StringName, StringName] (question ID -> option), exactly once.


func choose(questions: Array[NpcfPresentationQuestionDef], ctx: NpcfDialogueContext, on_done: Callable) -> void:
	var answers: Dictionary[StringName, StringName] = {}
	for q: NpcfPresentationQuestionDef in questions:
		answers[q.id] = rule_answer(q, ctx)
	on_done.call(answers)


## The answer of the first rule that matches, else the first option. Providers use it as their fallback too.
static func rule_answer(q: NpcfPresentationQuestionDef, ctx: NpcfDialogueContext) -> StringName:
	var no_args: Dictionary[StringName, Variant] = {}
	for r: NpcfPresentationRule in q.rules:
		if r == null:
			continue
		if r.intent != null and r.intent.id != ctx.intent:
			continue
		if r.result != &"" and (ctx.outcome == null or r.result != ctx.outcome.result):
			continue
		if r.condition != null and not NpcfConditions.check(ctx.world, ctx.view, r.condition, no_args, false):
			continue
		return r.answer
	return q.options[0] if not q.options.is_empty() else &""
