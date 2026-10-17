class_name CwShip
extends RefCounted
## Builds the CakeWorks demo ship from the cw location graph: a 256 x 192 room per location (floor, label,
## anchor, arrival area) and one navigation region over the rooms and a 40-px corridor along every edge.
## Copied from the framework's toy room sample (samples/toy_room/toy_room.gd) with CakeWorks sizes.

const ROOM_SIZE: Vector2 = Vector2(256, 192)
const CORRIDOR_WIDTH: float = 40.0
## Body layer the NPCs and the player use; arrival areas and hearing areas watch this layer.
const BODY_LAYER: int = 2


## Adds the rooms under `parent` and a navigation region over them. Locations missing from `centers` sit at the origin.
static func build_rooms(parent: Node2D, graph: NpcfLocationGraph, centers: Dictionary[StringName, Vector2]) -> void:
	if graph == null:
		return
	var outlines: Array[PackedVector2Array] = []
	for loc: NpcfLocationDef in graph.locations:
		var center: Vector2 = centers.get(loc.id, Vector2.ZERO)
		_add_room(parent, loc, center)
		outlines.append(_rect(center, ROOM_SIZE))
	for edge: NpcfEdgeDef in graph.edges:
		if edge.from_location == null or edge.to_location == null:
			continue
		var a: Vector2 = centers.get(edge.from_location.id, Vector2.ZERO)
		var b: Vector2 = centers.get(edge.to_location.id, Vector2.ZERO)
		outlines.append(_corridor(a, b))
	var region: NavigationRegion2D = NavigationRegion2D.new()
	region.navigation_polygon = _bake(outlines)
	parent.add_child(region)


## The NpcfAgent2D child of an NPC body, or null.
static func agent_of(body: Node) -> NpcfAgent2D:
	for child: Node in body.get_children():
		if child is NpcfAgent2D:
			var agent: NpcfAgent2D = child
			return agent
	return null


## The rectangle a room occupies, for the player's room lookup.
static func room_rect(center: Vector2) -> Rect2:
	return Rect2(center - ROOM_SIZE * 0.5, ROOM_SIZE)


static func _add_room(parent: Node2D, loc: NpcfLocationDef, center: Vector2) -> void:
	var floor: ColorRect = ColorRect.new()
	floor.position = center - ROOM_SIZE * 0.5
	floor.size = ROOM_SIZE
	floor.color = Color(0.2, 0.24, 0.2)
	parent.add_child(floor)
	var label: Label = Label.new()
	label.text = loc.display_name if loc.display_name != "" else String(loc.id)
	label.position = floor.position + Vector2(8, 6)
	parent.add_child(label)
	var anchor: NpcfLocationAnchor2D = NpcfLocationAnchor2D.new()
	anchor.location_id = loc.id
	anchor.position = center
	parent.add_child(anchor)
	var area: NpcfLocationArea2D = NpcfLocationArea2D.new()
	area.location_id = loc.id
	area.position = center
	area.collision_mask = BODY_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = ROOM_SIZE
	shape.shape = rect
	area.add_child(shape)
	parent.add_child(area)


static func _rect(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half: Vector2 = size * 0.5
	return PackedVector2Array([center + Vector2(-half.x, -half.y), center + Vector2(half.x, -half.y),
			center + Vector2(half.x, half.y), center + Vector2(-half.x, half.y)])


static func _corridor(a: Vector2, b: Vector2) -> PackedVector2Array:
	var along: Vector2 = (b - a).normalized()
	var across: Vector2 = Vector2(-along.y, along.x) * (CORRIDOR_WIDTH * 0.5)
	# Same winding as _rect (the bake expects consistent outlines).
	return PackedVector2Array([a - across, b - across, b + across, a + across])


static func _bake(outlines: Array[PackedVector2Array]) -> NavigationPolygon:
	var source: NavigationMeshSourceGeometryData2D = NavigationMeshSourceGeometryData2D.new()
	for outline: PackedVector2Array in outlines:
		source.add_traversable_outline(outline)
	var poly: NavigationPolygon = NavigationPolygon.new()
	NavigationServer2D.bake_from_source_geometry_data(poly, source)
	return poly
