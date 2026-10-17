# CakeWorks example

A small Godot project that uses the npcf addon with its own policy pack, `cw`. CakeWorks is a corporate ship that makes luxury cakes for distant clients, run round the clock by three crews. The NPCs have needs, goals and schedules, witness events, and spread rumors.

The framework project never imports this folder, so the two projects stay separate.

## Setup

The addon is copied into this project, not linked. Run the sync once, and again after changing `addons/npcf`:

```bash
bash tools/ci/sync_example.sh
```

Then open the project in Godot 4.7 or run the checks:

```bash
GODOT_BIN=/usr/local/bin/godot bash tools/ci/run_example.sh
```

## Where things are

| Path | What |
| --- | --- |
| `packs/cw/` | The `cw` pack. Every resource is generated. |
| `tools/build_cw_pack.gd` | Builds the pack. Change this script, then run `godot --headless --path . -s res://tools/build_cw_pack.gd`. Never hand-edit the `.tres` files. |
| `packs/cw/hooks/` | Hook scripts: the chat precondition and the news answer. |
| `packs/cw/scenarios/` | Scenarios. `starter.tres` (three NPCs, used by the acceptance suite) and `demo.tres` (seven NPCs, used by the demo). |
| `tests/` | gdUnit4 suites for the pack and its hooks. |

Check the pack against a scenario:

```bash
godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- check \
  --manifest res://packs/cw/pack.tres --scenario res://packs/cw/scenarios/starter.tres
```
