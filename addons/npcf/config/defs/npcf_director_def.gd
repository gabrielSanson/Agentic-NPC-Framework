@tool
class_name NpcfDirectorDef
extends Resource
## A pack's Director: macro variables, the rules that read them and an optional hook (R12).

@export var macros: Array[NpcfMacroVarDef] = []
@export var rules: Array[NpcfDirectorRuleDef] = []
## Optional script extending NpcfDirectorHook.
@export var hook: Script = null
## The hook runs on ticks where tick % hook_cadence_ticks == 0.
@export var hook_cadence_ticks: int = 60
