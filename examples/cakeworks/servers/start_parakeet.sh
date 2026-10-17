#!/usr/bin/env bash
# Runs our Parakeet FastAPI wrapper (parakeet/server.py) in the foreground on 127.0.0.1:8010.
# Usage: start_parakeet.sh [--cpu]
set -euo pipefail
source "$(dirname "$0")/common.sh"

CPU=0
for arg in "$@"; do
	case "$arg" in
		--cpu) CPU=1 ;;
		*) echo "unknown argument: $arg" >&2; exit 2 ;;
	esac
done

PY="$MODELS_DIR/parakeet-venv/bin/python"
if [ ! -x "$PY" ]; then
	echo "The Parakeet environment is missing. Run get_models.sh first." >&2
	exit 1
fi

if [ "$CPU" = 1 ]; then
	exec "$PY" "$SERVERS_DIR/parakeet/server.py" --host 127.0.0.1 --port "$PARAKEET_PORT" --cpu
fi
exec "$PY" "$SERVERS_DIR/parakeet/server.py" --host 127.0.0.1 --port "$PARAKEET_PORT"
