extends NpcfResolverHook
## Fixture: returns 7, which is not RUNNING, SUCCESS or FAILURE.


func resolve(_call: NpcfActionCallView, _world: NpcfWorldView, _elapsed: int) -> int:
	return 7
