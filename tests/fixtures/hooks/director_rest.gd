extends NpcfDirectorHook
## Fixture: when the idle pressure is at least 10, asks for a rest directive at priority 0.4 for 10 ticks.


func evaluate(macros: NpcfMacroView, _tick: int) -> Array[NpcfDirectiveSpec]:
	var out: Array[NpcfDirectiveSpec] = []
	if macros.value(&"toy.idle_pressure") >= 10.0:
		var spec: NpcfDirectiveSpec = NpcfDirectiveSpec.new()
		spec.goal = &"toy.rest"
		spec.priority = 0.4
		spec.duration_ticks = 10
		out.append(spec)
	return out
