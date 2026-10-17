#!/usr/bin/env bash
# Runs kev serve in the foreground on port 8009. The model is jaredpalmer/kev-4b, or the 0.8B model with --light.
# If KEV_API_KEY is set in the environment, kev serve requires it as a bearer token, and the provider sends it.
# Usage: start_kev.sh [--light]
set -euo pipefail
source "$(dirname "$0")/common.sh"

RUN_MODEL="$KEV_MODEL_FULL"
for arg in "$@"; do
	case "$arg" in
		--light) RUN_MODEL="$KEV_MODEL_LIGHT" ;;
		*) echo "unknown argument: $arg" >&2; exit 2 ;;
	esac
done

if [ ! -d "$MODELS_DIR/kev" ]; then
	echo "Kev is not installed. Run get_models.sh first." >&2
	exit 1
fi

cd "$MODELS_DIR/kev"
exec uv run --extra serve python -m kev.serve --run "$RUN_MODEL" --port "$KEV_PORT"
