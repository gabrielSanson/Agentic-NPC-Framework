class_name NpcfIntentHook
extends RefCounted
## Extension point: computes a dialogue rule outcome for an intent (task 19).
## Safe default on failure: the intent's declarative outcome, or no outcome.


func outcome(_view: NpcfNpcView, _intent: StringName, _speaker: StringName) -> NpcfRuleOutcome:
	return null
