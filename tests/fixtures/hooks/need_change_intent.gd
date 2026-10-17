extends NpcfIntentHook
## Fixture: returns a need change, which dialogue outcomes may not make.


func outcome(view: NpcfNpcView, _intent: StringName, _speaker: StringName) -> NpcfRuleOutcome:
	var o: NpcfRuleOutcome = NpcfRuleOutcome.new()
	o.result = &"toy.friendly"
	o.changes.append(NpcfStateChange.need_delta(view.npc_id(), &"toy.energy", -50))
	return o
