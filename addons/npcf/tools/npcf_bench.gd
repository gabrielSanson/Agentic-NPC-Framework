class_name NpcfBench
extends RefCounted
## Builds a bench population: N clones of a scenario's cast, each with its own copy of the archetype that decides
## every tick (decision_period_ticks = 1, one decision per game minute at one minute per tick). The clones are
## registered in the cloned manifest, so the loader validates them like any pack. Used by the bench command and
## the bench scene; tools only, never core.


## The cloned manifest and scenario. The cast refers to the clones registered in the manifest.
class Population extends RefCounted:
	var manifest: NpcfPackManifest = null
	var scenario: NpcfScenarioDef = null


## A population of `npcs` clones built from the scenario's cast in order (cast entry i % cast size).
static func population(manifest: NpcfPackManifest, scenario: NpcfScenarioDef, npcs: int) -> Population:
	var ns: String = str(manifest.pack_namespace)
	var source: Array[NpcfCastEntry] = []
	for entry: NpcfCastEntry in scenario.cast:
		if entry != null and entry.character != null:
			source.append(entry)
	var clone_manifest: NpcfPackManifest = manifest.duplicate(false) as NpcfPackManifest
	var characters: Array[NpcfCharacterDef] = []
	characters.assign(manifest.characters)
	var archetypes: Array[NpcfArchetypeDef] = []
	archetypes.assign(manifest.archetypes)
	var cast: Array[NpcfCastEntry] = []
	for i: int in npcs:
		if source.is_empty():
			break
		var entry: NpcfCastEntry = source[i % source.size()]
		var archetype: NpcfArchetypeDef = entry.character.archetype.duplicate(false) as NpcfArchetypeDef
		archetype.id = StringName("%s.bench_arch_%02d" % [ns, i])
		archetype.decision_period_ticks = 1
		var character: NpcfCharacterDef = NpcfCharacterDef.new()
		character.id = StringName("%s.bench_%02d" % [ns, i])
		character.archetype = archetype
		character.personalities.assign(entry.character.personalities)
		var cast_entry: NpcfCastEntry = NpcfCastEntry.new()
		cast_entry.character = character
		cast_entry.start_location = entry.start_location
		cast_entry.schedule = entry.schedule
		cast_entry.need_start.merge(entry.need_start)
		cast_entry.tags_add.assign(entry.tags_add)
		cast.append(cast_entry)
		characters.append(character)
		archetypes.append(archetype)
	clone_manifest.characters = characters
	clone_manifest.archetypes = archetypes
	var clone_scenario: NpcfScenarioDef = scenario.duplicate(false) as NpcfScenarioDef
	clone_scenario.cast = cast
	var out: Population = Population.new()
	out.manifest = clone_manifest
	out.scenario = clone_scenario
	return out


## The value at the given fraction of sorted samples (nearest rank). Samples must be sorted and non-empty.
static func percentile(sorted: Array[float], fraction: float) -> float:
	var rank: int = ceili(fraction * sorted.size()) - 1
	return sorted[clampi(rank, 0, sorted.size() - 1)]


## How many of `frames` frames of `frame_seconds` at `speed` would hit the per-frame tick cap while time is still
## owed, using the runtime's accumulator rule.
static func capped_frames(frames: int, frame_seconds: float, speed: float, interval: float, cap: int) -> int:
	var acc: float = 0.0
	var capped: int = 0
	for _f: int in frames:
		acc += frame_seconds * speed
		var steps: int = 0
		while acc >= interval and steps < cap:
			acc -= interval
			steps += 1
		if acc >= interval:
			capped += 1
	return capped
