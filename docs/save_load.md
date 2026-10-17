# Save and load

## API

- `Npcf.save_game(slot: String) -> Error`: writes the running world to a slot. Returns `ERR_UNCONFIGURED` when
  nothing runs, `ERR_INVALID_DATA` when an invariant fails (nothing is written) or the state cannot be encoded.
- `Npcf.load_game(slot: String, use_backup: bool = false) -> Error`: replaces the running world with the saved
  one. Needs `start()` first. Refused saves (wrong pack, pack major version, scenario or schema) return
  `ERR_FILE_CORRUPT` and emit `sim_error`; files and the running world stay as they were.
- Autosave: project setting `npcf/save/autosave_seconds` (default 300.0, 0 disables). It writes slot `autosave`
  from `advance_frame` when the real time reaches the interval. A failed autosave only emits `sim_error`.
- Slots are 1 to 64 characters of letters, digits, `_` and `-`.

## Files

Each slot is `<dir>/<slot>.json`, with `.json.tmp` during a write and `.json.bak` for the previous save. The
default `dir` is `user://saves`. A write goes: temp file (re-read and checked as JSON), delete the old backup,
rename the save to the backup, rename the temp file to the save. A crash between renames leaves the backup
and the temp file; `load_game(slot, true)` loads the backup.

## Layout

One JSON object with `schema_version` 1 (`NpcfSaveCodec`). Maps whose order the simulation depends on are
arrays of pairs in live order. Values are tagged arrays (`["i", "123"]`, `["n", "toy.kitchen"]`, ...), and 64-bit
integers are decimal strings. Saves never hold API keys, node paths or object references, and never use
`ResourceSaver`.

## Compatibility

A save loads only into the same pack namespace, the same major pack version and the same scenario ID, with the
same schema version. The seed is part of the save and is used to rebuild the world before its state is restored.

## Not saved

Decision records, action outcomes, dialogue turn records and turns in flight, the relationship change log, hook
failure counters and provider call records. Traces start empty after a load. The event log holds only events
after the load. Running actions load as not embodied; the runtime re-sends embodiment for registered agents.
