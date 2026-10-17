class_name NpcfDirectorHook
extends RefCounted
## Extension point: computes Director directives from macro variables (task 18).
## Safe default on failure: no directives for that tick.


func evaluate(_macros: NpcfMacroView, _tick: int) -> Array[NpcfDirectiveSpec]:
	return []
