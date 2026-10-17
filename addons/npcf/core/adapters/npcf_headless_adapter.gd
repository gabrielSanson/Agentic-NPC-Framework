class_name NpcfHeadlessAdapter
extends RefCounted
## The adapter set for runs without a scene: no NPC is ever embodied, an NPC perceives an event
## when it is at the event's location, and nothing is presented.


class Perception extends NpcfPerceptionAdapter:
	func can_perceive(npc: StringName, event: NpcfEventView, world: NpcfWorldView) -> bool:
		var at: StringName = event.location()
		return at != &"" and world.location_of(npc) == at

	func perceivers(event: NpcfEventView, world: NpcfWorldView, exclude: Dictionary[StringName, int]) -> Array[StringName]:
		var out: Array[StringName] = []
		var at: StringName = event.location()
		if at == &"":
			return out
		for id: StringName in world.npcs_at(at):
			if not exclude.has(id):
				out.append(id)
		return out


static func adapter_set() -> NpcfAdapterSet:
	return NpcfAdapterSet.make(NpcfMovementAdapter.new(), Perception.new(), NpcfPresentationAdapter.new())
