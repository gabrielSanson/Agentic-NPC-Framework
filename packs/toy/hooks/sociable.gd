extends NpcfConsiderationHook
## Scores how much an NPC wants to chat: its curiosity, scaled by the `scale` parameter.


func evaluate(view: NpcfNpcView, params: NpcfHookParams) -> float:
	var scale: float = params.get_float(&"scale", 1.0)
	return clampf(view.need_normalized(&"toy.curiosity") * scale, 0.0, 1.0)
