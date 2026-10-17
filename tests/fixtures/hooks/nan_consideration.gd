extends NpcfConsiderationHook
## Fixture: returns NaN, which is not a valid input.


func evaluate(_view: NpcfNpcView, _params: NpcfHookParams) -> float:
	return NAN
