class_name NpcfLocationIndex
extends RefCounted
## Precomputed all-pairs shortest paths over the location graph (Dijkstra from every location,
## ties broken by ascending location ID), plus tag lookups (design "4. Space").

var location_ids: Array[StringName] = []
var _tags: Dictionary[StringName, Array] = {}
## "from|to" -> travel ticks of the direct edge.
var _edge_ticks: Dictionary[String, int] = {}
var _adjacent: Dictionary[StringName, Array] = {}
## "from|to" -> shortest path.
var _paths: Dictionary[String, NpcfPath] = {}
## from -> to -> travel ticks of the shortest path (the same values as _paths, keyed without a string).
var _travel: Dictionary[StringName, Dictionary] = {}
## from -> tag -> nearest_with_tag result, filled on first use. The index is static once built.
var _nearest: Dictionary[StringName, Dictionary] = {}
## Shared empty tag list for unknown locations. Never mutate it.
static var _NO_TAGS: Array[StringName] = []


func _init(graph: NpcfLocationGraph = null) -> void:
	if graph == null:
		return
	for loc: NpcfLocationDef in graph.locations:
		if loc == null or loc.id == &"" or location_ids.has(loc.id):
			continue
		location_ids.append(loc.id)
		var tags: Array[StringName] = loc.tags.duplicate()
		_tags[loc.id] = tags
		_adjacent[loc.id] = [] as Array[StringName]
	location_ids.sort_custom(NpcfWorldState.name_less)
	for e: NpcfEdgeDef in graph.edges:
		if e == null or e.from_location == null or e.to_location == null or e.travel_ticks < 1:
			continue
		_add_edge(e.from_location.id, e.to_location.id, e.travel_ticks)
		if e.bidirectional:
			_add_edge(e.to_location.id, e.from_location.id, e.travel_ticks)
	for id: StringName in location_ids:
		var adj: Array[StringName] = _adjacent[id]
		adj.sort_custom(NpcfWorldState.name_less)
	for src: StringName in location_ids:
		_dijkstra(src)


func has_location(id: StringName) -> bool:
	return _tags.has(id)


func tags_of(id: StringName) -> Array[StringName]:
	var t: Array[StringName] = []
	var raw: Array = _tags.get(id, [])
	t.assign(raw)
	return t


func has_tag(id: StringName, tag: StringName) -> bool:
	var t: Array = _tags.get(id, _NO_TAGS)
	return t.has(tag)


## Travel ticks of the shortest path; 0 for the same location; -1 when unreachable or unknown.
func travel_ticks(from: StringName, to: StringName) -> int:
	if from == to:
		return 0 if has_location(from) else -1
	if not _travel.has(from):
		return -1
	var row: Dictionary = _travel[from]
	var t: int = row.get(to, -1)
	return t


## The shortest path, or null when unreachable. The same location gives an empty path.
func path(from: StringName, to: StringName) -> NpcfPath:
	if from == to and has_location(from):
		return NpcfPath.new()
	return _paths.get("%s|%s" % [from, to])


## Travel ticks of the direct edge from -> to, or -1.
func edge_ticks(from: StringName, to: StringName) -> int:
	return _edge_ticks.get("%s|%s" % [from, to], -1)


## The reachable location with `tag` nearest to `from` (ties by ID), or &"".
func nearest_with_tag(from: StringName, tag: StringName) -> StringName:
	if _nearest.has(from):
		var known: Dictionary = _nearest[from]
		if known.has(tag):
			var cached: StringName = known[tag]
			return cached
	var best: StringName = &""
	var best_ticks: int = -1
	for id: StringName in location_ids:
		if not has_tag(id, tag):
			continue
		var t: int = travel_ticks(from, id)
		if t < 0:
			continue
		if best_ticks < 0 or t < best_ticks:
			best = id
			best_ticks = t
	if not _nearest.has(from):
		_nearest[from] = {}
	var store: Dictionary = _nearest[from]
	store[tag] = best
	return best


## Locations reachable from any of `starts` (including the starts).
func reachable_from(starts: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in location_ids:
		for s: StringName in starts:
			if travel_ticks(s, id) >= 0:
				out.append(id)
				break
	return out


func _add_edge(from: StringName, to: StringName, ticks: int) -> void:
	if not _adjacent.has(from) or not _adjacent.has(to):
		return
	var key: String = "%s|%s" % [from, to]
	if _edge_ticks.has(key):
		_edge_ticks[key] = mini(_edge_ticks[key], ticks)
		return
	_edge_ticks[key] = ticks
	var adj: Array[StringName] = _adjacent[from]
	adj.append(to)


func _dijkstra(src: StringName) -> void:
	var row: Dictionary = {}
	_travel[src] = row
	var dist: Dictionary[StringName, int] = {src: 0}
	var prev: Dictionary[StringName, StringName] = {}
	var done: Dictionary[StringName, bool] = {}
	while true:
		# Pick the closest unfinished location; ties by ID (location_ids is sorted).
		var u: StringName = &""
		var best: int = -1
		for id: StringName in location_ids:
			if done.has(id) or not dist.has(id):
				continue
			if best < 0 or dist[id] < best:
				best = dist[id]
				u = id
		if best < 0:
			break
		done[u] = true
		var adj: Array[StringName] = _adjacent[u]
		for v: StringName in adj:
			var nd: int = dist[u] + _edge_ticks["%s|%s" % [u, v]]
			var prev_v: StringName = prev.get(v, &"")
			if not dist.has(v) or nd < dist[v] or (nd == dist[v] and String(u) < String(prev_v)):
				if done.has(v):
					continue
				dist[v] = nd
				prev[v] = u
	for dst: StringName in location_ids:
		if dst == src or not dist.has(dst):
			continue
		var p: NpcfPath = NpcfPath.new()
		p.ticks = dist[dst]
		var cur: StringName = dst
		while cur != src:
			p.nodes.push_front(cur)
			cur = prev[cur]
		_paths["%s|%s" % [src, dst]] = p
		row[dst] = p.ticks
