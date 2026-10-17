#!/usr/bin/env bash
# Runs llama-server with Gemma 4 12B (Q4_K_M) on 127.0.0.1:8090 in the foreground.
# Needs llama.cpp built with CUDA, Vulkan or Metal. --jinja is required for Gemma's chat template.
# Usage: start_gemma.sh [--cpu]    (--cpu offloads no layers: it runs, but slowly)
set -euo pipefail
source "$(dirname "$0")/common.sh"

NGL=99
for arg in "$@"; do
	case "$arg" in
		--cpu) NGL=0 ;;
		*) echo "unknown argument: $arg" >&2; exit 2 ;;
	esac
done

if ! command -v llama-server >/dev/null 2>&1; then
	echo "llama-server is not on PATH. Build llama.cpp (CUDA, Vulkan or Metal) and add its build/bin to PATH." >&2
	exit 1
fi

exec llama-server -hf "$GEMMA_MODEL" --jinja --host 127.0.0.1 --port "$GEMMA_PORT" -c 8192 -ngl "$NGL"
