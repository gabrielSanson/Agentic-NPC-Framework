class_name NpcfRng
extends RefCounted
## Keyed random streams (R1.5). Each (subsystem, entity, purpose) key has its own generator seeded
## from sha256(world seed | key), so adding an entity never changes another entity's draws.

var world_seed: int = 0
var _streams: Dictionary[String, RandomNumberGenerator] = {}


func _init(p_seed: int = 0) -> void:
	world_seed = p_seed


func stream(subsystem: StringName, entity: StringName, purpose: StringName) -> RandomNumberGenerator:
	var key: String = "%s|%s|%s" % [subsystem, entity, purpose]
	var existing: RandomNumberGenerator = _streams.get(key)
	if existing != null:
		return existing
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = NpcfRng.seed_for(world_seed, key)
	_streams[key] = rng
	return rng


## The seed of a stream: the first 15 hex digits of sha256("seed|subsystem|entity|purpose").
static func seed_for(p_world_seed: int, key: String) -> int:
	return ("%d|%s" % [p_world_seed, key]).sha256_text().substr(0, 15).hex_to_int()


## Stream keys in creation order, for saves and traces.
func keys() -> Array[String]:
	var out: Array[String] = []
	out.assign(_streams.keys())
	return out


## Drops every stream (before a restore).
func clear() -> void:
	_streams.clear()


## Stream rows in live order, [key, seed, state], for saves.
func export_streams() -> Array:
	var out: Array = []
	for key: String in _streams:
		var s: RandomNumberGenerator = _streams[key]
		out.append([key, s.seed, s.state])
	return out


## Adds a stream with its saved seed and state. Call in saved order.
func restore_stream(key: String, p_seed: int, p_state: int) -> void:
	var s: RandomNumberGenerator = RandomNumberGenerator.new()
	s.seed = p_seed
	s.state = p_state
	_streams[key] = s
