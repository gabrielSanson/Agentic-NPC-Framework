extends NpcfIntentHook
## Fixture: reveals a sighting at home_b, which the NPC holds no belief about.


func outcome(_view: NpcfNpcView, _intent: StringName, _speaker: StringName) -> NpcfRuleOutcome:
	var o: NpcfRuleOutcome = NpcfRuleOutcome.new()
	o.result = &"toy.no_news"
	o.revealed.append(NpcfFactRef.make(&"toy.home_b", &"toy.sighting"))
	return o
