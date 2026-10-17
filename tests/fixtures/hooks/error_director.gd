extends NpcfDirectorHook
## Fixture: calls a method on null at runtime.


func evaluate(_macros: NpcfMacroView, _tick: int) -> Array[NpcfDirectiveSpec]:
	var missing: NpcfMacroView = null
	var out: Array[NpcfDirectiveSpec] = []
	out.append(NpcfDirectiveSpec.new())
	out[0].priority = missing.value(&"toy.idle_pressure")
	return out
