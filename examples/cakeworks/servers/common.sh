#!/usr/bin/env bash
# Shared settings for the CakeWorks model servers. Sourced by the other scripts; not run on its own.
# Ports are fixed so the demo profiles (demo/profiles/*.tres) can name them. Every server binds to 127.0.0.1.
# Model IDs and file names marked "check on Hugging Face" were inferred when this was written; check them before use.

MODELS_DIR="${MODELS_DIR:-$HOME/npcf-models}"
SERVERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDS_FILE="$SERVERS_DIR/.pids"

GEMMA_PORT=8090
KEV_PORT=8009
PARAKEET_PORT=8010
BREEZE_PORT=8080

# Gemma 4 12B, Q4_K_M, pulled by llama-server on first start. Check on Hugging Face.
GEMMA_MODEL="ggml-org/gemma-4-12B-GGUF:Q4_K_M"
# Kev models for kev serve --run. Check on Hugging Face (the 0.8B ID is inferred).
KEV_MODEL_FULL="jaredpalmer/kev-4b"
KEV_MODEL_LIGHT="jaredpalmer/kev-0.8b"
# Breeze GGUF files under MODELS_DIR. Check the names on Hugging Face (inferred).
BREEZE_Q8_FILE="breeze-tts-2-q8_0.gguf"
BREEZE_Q4_FILE="breeze-tts-2-q4_k.gguf"
