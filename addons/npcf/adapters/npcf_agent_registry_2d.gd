class_name NpcfAgentRegistry2D
extends RefCounted
## Maps NPC IDs to their scene agents. Holds weak references, so a freed agent drops out by itself.
## The runtime owns one; the 2D adapters read it. The player is found by group, not by a node link.
## The player node may define `func npcf_facing_npc() -> StringName` to say which NPC it faces (dialogue addressee).

## The player's entity ID, set by the runtime at start (empty when the pack has no player).
var player_entity: StringName = &""
## A node in the scene tree the registry can search when no agent is registered yet (the runtime sets it).
var scene_source: Node = null
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
	var tree: SceneTree = _tree()
	if tree == null:
		return Vector2.ZERO
	for node: Node in tree.get_nodes_in_group(&"npcf_anchors"):
		if node is NpcfLocationAnchor2D:
			var anchor: NpcfLocationAnchor2D = node
			if anchor.location_id == location:
				return anchor.global_position
	return Vector2.ZERO


## The tree of the first registered agent in the tree, else of the scene source; null when neither is.
func _tree() -> SceneTree:
	for npc: StringName in ids():
		var a: NpcfAgent2D = agent(npc)
		if a != null and a.is_inside_tree():
			return a.get_tree()
	if scene_source != null and scene_source.is_inside_tree():
		return scene_source.get_tree()
	return null


func _player_body() -> Node2D:
	var tree: SceneTree = _tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(&"npcf_player"):
		if node is Node2D:
			var body: Node2D = node
			return body
	return null
