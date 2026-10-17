#!/usr/bin/env bash
# Example CI (examples/cakeworks): sync the addon copies, import, check the cw pack against its
# scenarios, then run the example's gdUnit4 suites. Requires GODOT_BIN (absolute path to Godot 4.7+).
# The example gets strictness from its own directory_rules; the framework scripts do not run here.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
export GODOT_BIN
EX=examples/cakeworks

bash tools/ci/sync_example.sh

echo "== import"
"$GODOT_BIN" --headless --path "$EX" --import >/dev/null 2>&1 || true

echo "== check cw pack (starter scenario)"
"$GODOT_BIN" --headless --path "$EX" -s res://addons/npcf/tools/npcf_cli.gd -- check \
	--manifest res://packs/cw/pack.tres --scenario res://packs/cw/scenarios/starter.tres

echo "== gdUnit4 (example tests)"
cd "$EX"
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests "$@"
