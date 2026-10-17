# Agentic NPC Framework

`npcf`: a Godot addon for believable, explainable NPC societies. Work in progress; see the open milestone pull requests.

## Quick start

1. Enable the addon: copy `addons/npcf` into your Godot 4.7 project and enable the plugin in Project Settings.
2. Run the toy day headless:
   ```bash
   godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- run \
     --manifest res://packs/toy/pack.tres --scenario res://packs/toy/scenarios/basic.tres --seed 7 --ticks 1440
   ```
   (The same run is in `tools/ci/run_tests.sh`. Run it from the repo root.)
3. Open `samples/toy_room/main.tscn` to see the same pack running in a 2D room.
4. Read an NPC's trace, either in code with `Npcf.trace(npc)` or from the CLI:
   ```bash
   godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- trace \
     --manifest res://packs/toy/pack.tres --scenario res://packs/toy/scenarios/basic.tres --seed 7 --tick 600 --npc toy.ana
   ```
5. Try CakeWorks: run `bash tools/ci/sync_example.sh`, open `examples/cakeworks` in Godot, and read `examples/cakeworks/README.md`.

## Trust model

Pack hook scripts (`packs/**/*.gd`) are code. They run with full engine rights, so only load packs you trust.
Model servers bind to 127.0.0.1 only. API keys come from environment variables only (`key_env`); no key is ever written to a file.
