class_name NpcfRunningAction
extends RefCounted
## One action an NPC is performing. Stored on the NPC while it runs; travel fields are used only
## by npcf.move_to.

var call: NpcfActionCall
var def: NpcfActionDef
var started_tick: int = 0
var elapsed: int = 0
var finished: bool = false
var timeout: int = 0
# travel (npcf.move_to only)
## Locations after the start, in order.
var path: Array[StringName] = []
## Next location to reach.
var path_index: int = 0
var edge_elapsed: int = 0
var last_location: StringName = &""
var embodied: bool = false
