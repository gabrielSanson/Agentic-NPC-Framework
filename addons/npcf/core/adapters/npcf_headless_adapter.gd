class_name NpcfHeadlessAdapter
extends RefCounted
## The adapter set for runs without a scene: no NPC is ever embodied, an NPC perceives an event
## when it is at the event's location, and nothing is presented.


class Perception extends NpcfPerceptionAdapter:
	func can_perceive(npc: StringName, event: NpcfEventView, world: NpcfWorldView) -> bool:
		var at: StringName = event.location()
		return at != &"" and world.location_of(npc) == at


static func adapter_set() -> NpcfAdapterSet:
	return NpcfAdapterSet.make(NpcfMovementAdapter.new(), Perception.new(), NpcfPresentationAdapter.new())
