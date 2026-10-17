extends NpcfResolverHook
## Fixture: calls a method on null at runtime. Returning 0 would be an invalid status anyway.


func resolve(_call: NpcfActionCallView, _world: NpcfWorldView, _elapsed: int) -> int:
	var missing: NpcfActionCallView = null
	return missing.call_id()
