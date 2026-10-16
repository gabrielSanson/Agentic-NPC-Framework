@tool
class_name NpcfActionDef
extends Resource
## An action NPCs can perform, with its typed arguments, preconditions and effects (R9.1).

## RULES: chosen by planners. DIALOGUE: presentation only, offered to the LLM.
## DESIGNER_ONLY: started only by game code.
enum Tier { RULES, DIALOGUE, DESIGNER_ONLY }

@export var id: StringName = &""
@export var tier: Tier = Tier.RULES
@export var args: Array[NpcfFieldDef] = []
## Must be greater than 0. Used by the single-step planner: A(a) = C(a) * M_a / cost.
@export var cost: float = 1.0
@export var duration_ticks: int = 1
@export var cooldown_ticks: int = 0
## -1 means duration_ticks + 30.
@export var timeout_ticks: int = -1
## At most one of required_location and required_location_tag.
@export var required_location: NpcfLocationDef = null
@export var required_location_tag: StringName = &""
@export var preconditions: Array[NpcfConditionDef] = []
@export var start_effects: Array[NpcfEffectDef] = []
@export var end_effects: Array[NpcfEffectDef] = []
@export var cleanup_effects: Array[NpcfEffectDef] = []
## Need ID -> change applied every tick while the action runs.
@export var per_tick_need_deltas: Dictionary[StringName, int] = {}
@export var considerations: Array[NpcfConsiderationDef] = []
## Script extending NpcfResolverHook; decides the outcome headless and offscreen.
@export var resolver: Script = null
## Animation hint passed to the presentation adapter.
@export var presentation_cue: StringName = &""


## The timeout in ticks after the defaults are applied.
func effective_timeout() -> int:
	return timeout_ticks if timeout_ticks >= 0 else duration_ticks + 30
