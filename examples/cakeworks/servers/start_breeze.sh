#!/usr/bin/env bash
# Runs breeze-server in the foreground on 127.0.0.1:8080. It has no authentication, so it is always bound to
# 127.0.0.1. The weights are non-commercial: the demo refuses voice output unless --allow-non-commercial is passed.
# Usage: start_breeze.sh [--light]    (--light uses the q4_k weights instead of q8_0)
set -euo pipefail
source "$(dirname "$0")/common.sh"

MODEL_FILE="$BREEZE_Q8_FILE"
for arg in "$@"; do
	case "$arg" in
		--light) MODEL_FILE="$BREEZE_Q4_FILE" ;;
		*) echo "unknown argument: $arg" >&2; exit 2 ;;
	esac
done

BIN="$MODELS_DIR/Breeze-TTS-2.cpp/build/breeze-server"
MODEL="$MODELS_DIR/$MODEL_FILE"
if [ ! -x "$BIN" ]; then
	echo "breeze-server is not built. Run get_models.sh first." >&2
	exit 1
fi
if [ ! -f "$MODEL" ]; then
	echo "Missing weights: $MODEL. Set BREEZE_Q8_URL or BREEZE_Q4_URL and run get_models.sh." >&2
	exit 1
fi

exec "$BIN" "$MODEL" --host 127.0.0.1 --port "$BREEZE_PORT"
