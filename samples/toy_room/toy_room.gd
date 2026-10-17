class_name ToyRoom
extends RefCounted
## Builds the toy room sample's geometry from a location graph: a 160 x 120 room per location (floor, label,
## anchor, arrival area) and one navigation region over the rooms and a 40-px corridor along every edge.
## Nothing is placed by hand except the room centers the caller passes in.

const ROOM_SIZE: Vector2 = Vector2(160, 120)
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
		_add_room(parent, loc.id, center)
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


static func _add_room(parent: Node2D, id: StringName, center: Vector2) -> void:
	var floor: ColorRect = ColorRect.new()
	floor.position = center - ROOM_SIZE * 0.5
	floor.size = ROOM_SIZE
	floor.color = Color(0.2, 0.24, 0.2)
	parent.add_child(floor)
	var label: Label = Label.new()
	label.text = String(id)
	label.position = floor.position + Vector2(6, 4)
	parent.add_child(label)
	var anchor: NpcfLocationAnchor2D = NpcfLocationAnchor2D.new()
	anchor.location_id = id
	anchor.position = center
	parent.add_child(anchor)
	var area: NpcfLocationArea2D = NpcfLocationArea2D.new()
	area.location_id = id
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
	# Same winding as _rect (the bake expects consistent outlines); the room and corridor outlines must agree.
	return PackedVector2Array([a - across, b - across, b + across, a + across])


static func _bake(outlines: Array[PackedVector2Array]) -> NavigationPolygon:
	var source: NavigationMeshSourceGeometryData2D = NavigationMeshSourceGeometryData2D.new()
	for outline: PackedVector2Array in outlines:
		source.add_traversable_outline(outline)
	var poly: NavigationPolygon = NavigationPolygon.new()
	NavigationServer2D.bake_from_source_geometry_data(poly, source)
	return poly
