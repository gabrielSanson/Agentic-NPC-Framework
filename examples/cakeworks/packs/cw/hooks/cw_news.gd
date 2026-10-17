extends NpcfIntentHook
## Asking for news: reveals up to two complaints this NPC believes were made by crew members.
## With at least one reveal the result is cw.has_news, otherwise cw.no_news.

const CREW: Array[StringName] = [
	&"cw.mira", &"cw.oskar", &"cw.juno", &"cw.tamsin",
	&"cw.rafi", &"cw.bea", &"cw.lev", &"cw.ines",
]
const MAX_REVEALS: int = 2


func outcome(view: NpcfNpcView, _intent: StringName, _speaker: StringName) -> NpcfRuleOutcome:
	var o: NpcfRuleOutcome = NpcfRuleOutcome.new()
	o.result = &"cw.no_news"
	for who: StringName in CREW:
		if o.revealed.size() >= MAX_REVEALS:
			break
		var read: NpcfFactRead = view.fact(who, &"cw.complained")
		if read.value == true and read.confidence > 0:
			o.revealed.append(NpcfFactRef.make(who, &"cw.complained"))
	if o.revealed.size() > 0:
		o.result = &"cw.has_news"
	return o
