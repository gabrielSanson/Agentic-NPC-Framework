extends NpcfIntentHook
## Asking for news: the first location (by ID) where this NPC believes a sighting was made.

const LOCATIONS: PackedStringArray = ["toy.home_a", "toy.home_b", "toy.workshop", "toy.yard"]


func outcome(view: NpcfNpcView, _intent: StringName, _speaker: StringName) -> NpcfRuleOutcome:
	for loc_name: String in LOCATIONS:
		var loc: StringName = StringName(loc_name)
		var read: NpcfFactRead = view.fact(loc, &"toy.sighting")
		var seen: bool = read.value == true
		if seen and read.confidence > 0:
			var o: NpcfRuleOutcome = NpcfRuleOutcome.new()
			o.result = &"toy.has_news"
			o.revealed.append(NpcfFactRef.make(loc, &"toy.sighting"))
			return o
	var none: NpcfRuleOutcome = NpcfRuleOutcome.new()
	none.result = &"toy.no_news"
	return none
