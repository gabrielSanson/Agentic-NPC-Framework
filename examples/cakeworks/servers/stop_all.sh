#!/usr/bin/env bash
# Stops the servers that start_all.sh started (PIDs in servers/.pids). Each start script execs its server, so the PID
# is the server itself. Kev runs under uv, which may leave a Python child behind: check for it by hand.
# Usage: stop_all.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [ ! -f "$PIDS_FILE" ]; then
	echo "No servers recorded."
	exit 0
fi

while read -r name pid; do
	if kill -0 "$pid" 2>/dev/null; then
		kill "$pid"
		echo "stopped $name ($pid)"
	else
		echo "$name was not running"
	fi
done < "$PIDS_FILE"
rm -f "$PIDS_FILE"
