class_name NpcfAdapters2D
extends RefCounted
## Builds the 2D adapter set on one agent registry. With no agents registered it behaves exactly like
## the headless set: nothing is embodied, perception is by location, nothing is presented.


static func make_set(registry: NpcfAgentRegistry2D) -> NpcfAdapterSet:
	return NpcfAdapterSet.make(NpcfMovementAdapter2D.new(registry), NpcfPerceptionAdapter2D.new(registry),
			NpcfPresentationAdapter2D.new(registry))
