class_name NpcfAdapterSet
extends RefCounted
## The three adapters a world talks to. The world never reaches into the presentation layer
## except through these.

var movement: NpcfMovementAdapter
var perception: NpcfPerceptionAdapter
var presentation: NpcfPresentationAdapter


static func make(m: NpcfMovementAdapter, p: NpcfPerceptionAdapter, pr: NpcfPresentationAdapter) -> NpcfAdapterSet:
	var s: NpcfAdapterSet = NpcfAdapterSet.new()
	s.movement = m
	s.perception = p
	s.presentation = pr
	return s
