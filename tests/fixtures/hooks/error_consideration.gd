extends NpcfConsiderationHook
## Fixture: calls a method on null at runtime (the runner must return 0.0 and count one failure).


func evaluate(_view: NpcfNpcView, _params: NpcfHookParams) -> float:
	var missing: NpcfNpcView = null
	return float(missing.npc_id().length())
