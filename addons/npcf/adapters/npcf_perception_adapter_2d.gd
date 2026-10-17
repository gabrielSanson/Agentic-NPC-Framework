class_name NpcfPerceptionAdapter2D
extends NpcfPerceptionAdapter
## Hearing for embodied NPCs: an event is perceived when an actor's body is inside the NPC's hearing area.
## Otherwise (offscreen NPCs, or no body for any actor) an NPC perceives events at its own location.

var registry: NpcfAgentRegistry2D


func _init(p_registry: NpcfAgentRegistry2D) -> void:
	registry = p_registry


func can_perceive(npc: StringName, event: NpcfEventView, world: NpcfWorldView) -> bool:
	var a: NpcfAgent2D = registry.agent(npc)
	var perception: NpcfAreaPerception2D = a.perception() if a != null else null
	if perception != null:
		var bodies: Array[Node2D] = []
		for actor: StringName in event.actors():
			var body: Node2D = registry.body_of(actor)
			if body != null:
				bodies.append(body)
		if not bodies.is_empty():
			for body: Node2D in bodies:
				if perception.hears(body):
					return true
			return false
	var at: StringName = event.location()
	return at != &"" and world.location_of(npc) == at
