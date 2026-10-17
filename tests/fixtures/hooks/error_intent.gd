extends NpcfIntentHook
## Fixture: calls a method on null at runtime, after naming an outcome.


func outcome(_view: NpcfNpcView, _intent: StringName, _speaker: StringName) -> NpcfRuleOutcome:
	var missing: NpcfNpcView = null
	var o: NpcfRuleOutcome = NpcfRuleOutcome.new()
	o.result = &"toy.bogus"
	o.changes.append(NpcfStateChange.rel_delta(missing.npc_id(), &"toy.player", &"toy.trust", 1))
	return o
