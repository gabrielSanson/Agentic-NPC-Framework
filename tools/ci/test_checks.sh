#!/usr/bin/env bash
# Proves each CI check fails on a known violation. Each fixture in tools/ci/fixtures/ is copied to
# the path named in its first line ("# place: <path>"), the named check runs and must exit non-zero,
# then the fixture is removed again. tools/ci/fixtures/ has a .gdignore so Godot never imports it.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
status=0
for fixture in tools/ci/fixtures/*.fixture; do
	place=$(sed -n '1s/^[#;] place: //p' "$fixture")
	check=$(sed -n '2s/^[#;] check: //p' "$fixture")
	mkdir -p "$(dirname "$place")"
	tail -n +3 "$fixture" > "$place"
	if "$GODOT_BIN" --headless --path . -s "res://tools/ci/$check.gd" >/tmp/npcf_fixture.log 2>&1; then
		echo "FAIL $(basename "$fixture"): $check passed but should have failed"
		status=1
	else
		echo "ok   $(basename "$fixture"): $check failed as expected: $(grep -m1 "$place" /tmp/npcf_fixture.log | sed 's/^.*: \([a-z-]*\): /\1: /')"
	fi
	rm -f "$place"
	rmdir -p --ignore-fail-on-non-empty "$(dirname "$place")" 2>/dev/null || true
done
exit $status
