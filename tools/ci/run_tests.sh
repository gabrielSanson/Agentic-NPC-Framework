#!/usr/bin/env bash
# Runs every CI step locally or in CI: import, type check, boundary check, hook lint, check-script
# fixtures, then the gdUnit4 suites.
# Requires GODOT_BIN (absolute path to a Godot 4.7+ binary); defaults to `godot` on PATH.
#
# gdUnit4 refuses --headless unless --ignoreHeadlessMode is passed; the framework suites use no
# UI input events, so the flag is safe here.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
export GODOT_BIN

step() { echo; echo "== $*"; }

step "import"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

step "check_types"
"$GODOT_BIN" --headless --path . -s res://tools/ci/check_types.gd

step "check_boundaries"
"$GODOT_BIN" --headless --path . -s res://tools/ci/check_boundaries.gd

step "lint_hooks"
"$GODOT_BIN" --headless --path . -s res://tools/ci/lint_hooks.gd

step "check-script fixtures"
bash tools/ci/test_checks.sh

step "gdUnit4"
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests "$@"

step "toy day (CLI, 1440 ticks)"
"$GODOT_BIN" --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- run \
	--manifest res://packs/toy/pack.tres --scenario res://packs/toy/scenarios/basic.tres --seed 7 --ticks 1440
