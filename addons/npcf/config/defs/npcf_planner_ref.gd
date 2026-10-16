@tool
class_name NpcfPlannerRef
extends Resource
## Names the planner an archetype or character uses.

## SINGLE_STEP: `npcf.single_step`. SCRIPT: `npcf.script`. HOOK: a pack NpcfPlannerHook script.
enum Kind { SINGLE_STEP, SCRIPT, HOOK }

@export var kind: Kind = Kind.SINGLE_STEP
@export var hook: Script = null


## The planner's ID as it appears in traces.
func planner_id() -> StringName:
	match kind:
		Kind.SCRIPT:
			return &"npcf.script"
		Kind.HOOK:
			return StringName(hook.resource_path) if hook != null else &"npcf.hook"
	return &"npcf.single_step"
