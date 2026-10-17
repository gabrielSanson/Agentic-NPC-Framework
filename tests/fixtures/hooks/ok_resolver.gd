extends NpcfResolverHook
## Fixture: runs for three ticks, then succeeds.


func resolve(_call: NpcfActionCallView, _world: NpcfWorldView, elapsed: int) -> int:
	return RUNNING if elapsed < 3 else SUCCESS
