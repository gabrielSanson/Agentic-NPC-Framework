extends SceneTree
## Command line for pack authors and CI (R2.5, R12.1). Usage:
##   godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- <command> [options]
##   check   --manifest P [--scenario S]          validate a pack (and a scenario) and print errors
##   resolve --manifest P --scenario S --npc ID   print one resolved cast entry as JSON
##   run     --manifest P --scenario S --seed N --ticks T [--log PATH]
##                                                run a headless world and check invariants
## Exit codes: 0 success, 1 errors found, 2 usage.

const USAGE: String = """usage: npcf_cli.gd -- <command> [options]
  check   --manifest P [--scenario S]
  resolve --manifest P --scenario S --npc ID
  run     --manifest P --scenario S --seed N --ticks T [--log PATH]"""


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var code: int = 2
	if args.is_empty():
		print(USAGE)
	else:
		match args[0]:
			"check":
				code = _check(args)
			"resolve":
				code = _resolve(args)
			"run":
				code = _run(args)
			_:
				print(USAGE)
	quit(code)


func _check(args: PackedStringArray) -> int:
	var manifest_path: String = _option(args, "--manifest")
	if manifest_path == "":
		print(USAGE)
		return 2
	var loaded: Array = _load_pack(manifest_path, _option(args, "--scenario"))
	var pack: NpcfLoadedPack = loaded[0]
	var errors: Array[NpcfConfigError] = loaded[1]
	if not errors.is_empty():
		return _print_errors(errors)
	print("ok: %d definitions" % _definition_count(pack))
	return 0


func _resolve(args: PackedStringArray) -> int:
	var manifest_path: String = _option(args, "--manifest")
	var scenario_path: String = _option(args, "--scenario")
	var npc_id: String = _option(args, "--npc")
	if manifest_path == "" or scenario_path == "" or npc_id == "":
		print(USAGE)
		return 2
	var loaded: Array = _load_pack(manifest_path, scenario_path)
	var pack: NpcfLoadedPack = loaded[0]
	var errors: Array[NpcfConfigError] = loaded[1]
	if not errors.is_empty():
		return _print_errors(errors)
	var scenario: NpcfScenarioDef = ResourceLoader.load(scenario_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	for entry: NpcfCastEntry in scenario.cast:
		if entry != null and entry.character != null and String(entry.character.id) == npc_id:
			var resolved: NpcfResolvedCharacter = NpcfResolver.resolve(entry)
			print(JSON.stringify(pack.to_debug_dict(resolved), "  ", true))
			return 0
	printerr("npcf: no cast entry for \"%s\" in %s" % [npc_id, scenario_path])
	return 1


func _run(args: PackedStringArray) -> int:
	var manifest_path: String = _option(args, "--manifest")
	var scenario_path: String = _option(args, "--scenario")
	if manifest_path == "" or scenario_path == "" or not _option(args, "--ticks").is_valid_int():
		print(USAGE)
		return 2
	var seed_value: int = _option(args, "--seed").to_int()
	var ticks: int = _option(args, "--ticks").to_int()
	var loaded: Array = _load_pack(manifest_path, scenario_path)
	var pack: NpcfLoadedPack = loaded[0]
	var errors: Array[NpcfConfigError] = loaded[1]
	if not errors.is_empty():
		return _print_errors(errors)
	var scenario: NpcfScenarioDef = ResourceLoader.load(scenario_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	var world: NpcfWorld = NpcfWorldBuilder.build(pack, scenario, seed_value)
	var started: int = 0
	var finished: int = 0
	for _i: int in ticks:
		var report: NpcfTickReport = world.step()
		if not report.invariant_failures.is_empty():
			for f: NpcfInvariantFailure in report.invariant_failures:
				printerr(f.format())
			world.dispose()
			return 1
		started += report.started.size()
		finished += report.finished.size()
	var log_path: String = _option(args, "--log")
	if log_path != "":
		var file: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
		if file == null:
			printerr("npcf: cannot write %s" % log_path)
			world.dispose()
			return 1
		file.store_string(world.events.log_text() + "\n")
	print("ran %d ticks: %d events, %d actions started, %d finished" % [ticks, world.events.log.size(), started, finished])
	world.dispose()
	return 0


## Loads a manifest and, when given, a scenario. Returns [pack or null, errors].
func _load_pack(manifest_path: String, scenario_path: String) -> Array:
	var loader: NpcfPackLoader = NpcfPackLoader.new()
	var errors: Array[NpcfConfigError] = []
	var manifest: NpcfPackManifest = ResourceLoader.load(manifest_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	if manifest == null:
		errors.append(NpcfConfigError.make(manifest_path, "", "not a pack manifest", "pass an NpcfPackManifest .tres file"))
		return [null, errors]
	var result: NpcfLoadResult = loader.load_pack(manifest)
	errors.append_array(result.errors)
	if not result.ok or scenario_path == "":
		return [result.pack, errors]
	var scenario: NpcfScenarioDef = ResourceLoader.load(scenario_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfScenarioDef
	if scenario == null:
		errors.append(NpcfConfigError.make(scenario_path, "", "not a scenario", "pass an NpcfScenarioDef .tres file"))
		return [result.pack, errors]
	errors.append_array(loader.check_scenario(result.pack, scenario))
	return [result.pack, errors]


func _print_errors(errors: Array[NpcfConfigError]) -> int:
	for e: NpcfConfigError in errors:
		printerr(e.format())
	printerr("%d error(s)" % errors.size())
	return 1


func _definition_count(pack: NpcfLoadedPack) -> int:
	var m: NpcfPackManifest = pack.manifest
	var locations: int = m.location_graph.locations.size() if m.location_graph != null else 0
	return m.facts.size() + m.needs.size() + m.event_kinds.size() + m.goals.size() + m.actions.size() \
		+ m.archetypes.size() + m.personalities.size() + m.characters.size() + m.schedules.size() \
		+ m.reactions.size() + m.invariants.size() + locations


## The value after `name` in the user arguments, or "" when absent.
func _option(args: PackedStringArray, name: String) -> String:
	var i: int = args.find(name)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return ""
