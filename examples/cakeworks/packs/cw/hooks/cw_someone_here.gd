extends NpcfConditionHook
## True when another crew member stands at the actor's location. The precondition for cw.chat.
## The crew list is fixed by the pack, so the check is deterministic and needs no world access.

const CREW: Array[StringName] = [
	&"cw.mira", &"cw.oskar", &"cw.juno", &"cw.tamsin",
	&"cw.rafi", &"cw.bea", &"cw.lev", &"cw.ines",
]


func check(view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> bool:
	var here: StringName = view.location()
	if here == &"":
		return false
	for other: StringName in CREW:
		if other != view.npc_id() and view.location_of(other) == here:
			return true
	return false
