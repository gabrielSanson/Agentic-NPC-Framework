class_name NpcfAgentRegistry2D
extends RefCounted
## Maps NPC IDs to their scene agents. Holds weak references, so a freed agent drops out by itself.
## The runtime owns one; the 2D adapters read it. The player is found by group, not by a node link.

## The player's entity ID, set by the runtime at start (empty when the pack has no player).
var player_entity: StringName = &""
var _agents: Dictionary[StringName, WeakRef] = {}


func add(npc: StringName, agent: NpcfAgent2D) -> void:
	_agents[npc] = weakref(agent)


func remove(npc: StringName) -> void:
	_agents.erase(npc)


## The agent for an NPC, or null when none is registered or the agent was freed.
func agent(npc: StringName) -> NpcfAgent2D:
	var ref: WeakRef = _agents.get(npc)
	if ref == null:
		return null
	var obj: Object = ref.get_ref()
	if obj == null:
		_agents.erase(npc)
		return null
	if obj is NpcfAgent2D:
		var a: NpcfAgent2D = obj
		return a
	return null


## The registered NPC IDs that still have a live agent, sorted.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for npc: StringName in _agents.keys():
		if agent(npc) != null:
			out.append(npc)
	out.sort_custom(NpcfWorldState.name_less)
	return out


## The body a perceiver can hear: an NPC's agent body, or a node in group npcf_player for the player.
func body_of(entity: StringName) -> Node2D:
	var a: NpcfAgent2D = agent(entity)
	if a != null:
		return a.body()
	if player_entity != &"" and entity == player_entity:
		return _player_body()
	return null


## The position of the first anchor with this location ID, searched from any registered agent's tree.
func anchor_position(location: StringName) -> Vector2:
	for npc: StringName in ids():
		var a: NpcfAgent2D = agent(npc)
		if a == null or not a.is_inside_tree():
			continue
		for node: Node in a.get_tree().get_nodes_in_group(&"npcf_anchors"):
			if node is NpcfLocationAnchor2D:
				var anchor: NpcfLocationAnchor2D = node
				if anchor.location_id == location:
					return anchor.global_position
	return Vector2.ZERO


func _player_body() -> Node2D:
	for npc: StringName in ids():
		var a: NpcfAgent2D = agent(npc)
		if a == null or not a.is_inside_tree():
			continue
		for node: Node in a.get_tree().get_nodes_in_group(&"npcf_player"):
			if node is Node2D:
				var body: Node2D = node
				return body
	return null
