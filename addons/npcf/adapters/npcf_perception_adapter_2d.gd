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


## Embodied NPCs are asked through can_perceive. Offscreen NPCs have no agent, so they perceive only
## at the event's location, which the location index gives directly.
func perceivers(event: NpcfEventView, world: NpcfWorldView, exclude: Dictionary[StringName, int]) -> Array[StringName]:
	var out: Array[StringName] = []
	var at: StringName = event.location()
	if at != &"":
		for id: StringName in world.npcs_at(at):
			if not exclude.has(id) and registry.agent(id) == null:
				out.append(id)
	for id: StringName in world.npc_ids():
		if exclude.has(id) or registry.agent(id) == null:
			continue
		if can_perceive(id, event, world):
			out.append(id)
	out.sort_custom(NpcfWorldState.name_less)
	return out


## NPCs with a hearing area that hears the speaker's body, plus offscreen NPCs at the speaker's location.
func audible_npcs(entity: StringName, world: NpcfWorldView) -> Array[StringName]:
	var out: Array[StringName] = []
	var body: Node2D = registry.body_of(entity)
	for id: StringName in world.npc_ids():
		var a: NpcfAgent2D = registry.agent(id)
		if a == null or body == null:
			continue
		var perception: NpcfAreaPerception2D = a.perception()
		if perception != null and perception.hears(body):
			out.append(id)
	var at: StringName = world.location_of(entity)
	if at != &"":
		for id: StringName in world.npcs_at(at):
			if registry.agent(id) == null and not out.has(id):
				out.append(id)
	out.sort_custom(NpcfWorldState.name_less)
	return out


## The NPC the speaker's body faces, from an optional npcf_facing_npc() method on its node, else &"".
func facing_npc(entity: StringName, _world: NpcfWorldView) -> StringName:
	var body: Node2D = registry.body_of(entity)
	if body != null and body.has_method(&"npcf_facing_npc"):
		var r: Variant = body.call(&"npcf_facing_npc")
		if typeof(r) == TYPE_STRING_NAME:
			var s: StringName = r
			return s
	return &""
