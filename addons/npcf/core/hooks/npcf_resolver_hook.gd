class_name NpcfResolverHook
extends RefCounted
## Extension point: decides how a running action ends when no scene presents it (headless and
## offscreen). Called once per tick while the action runs. Return RUNNING, SUCCESS or FAILURE.
## Safe default on failure: FAILURE. A runtime error makes the call return 0, which is not a valid
## status, so failures are always detected.

const RUNNING: int = 1
const SUCCESS: int = 2
const FAILURE: int = 3


func resolve(_call: NpcfActionCallView, _world: NpcfWorldView, _elapsed: int) -> int:
	return SUCCESS
