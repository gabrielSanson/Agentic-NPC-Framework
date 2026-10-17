class_name NpcfLegalActions
extends RefCounted
## The actions an NPC may start right now under its own view: preconditions hold under the read
## rule, the cooldown has expired and the tier is allowed (R9.2). Location requirements are not
## part of legality; planners add `npcf.move_to` instead.

var actions: Array[NpcfActionDef] = []


func has(id: StringName) -> bool:
	for a: NpcfActionDef in actions:
		if a.id == id:
			return true
	return false


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for a: NpcfActionDef in actions:
		out.append(a.id)
	return out
