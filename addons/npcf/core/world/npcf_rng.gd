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
