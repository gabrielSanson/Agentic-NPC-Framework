#!/usr/bin/env bash
# Shared settings for the CakeWorks model servers. Sourced by the other scripts; not run on its own.
# Ports are fixed so the demo profiles (demo/profiles/*.tres) can name them. Every server binds to 127.0.0.1.

MODELS_DIR="${MODELS_DIR:-$HOME/npcf-models}"
SERVERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDS_FILE="$SERVERS_DIR/.pids"

GEMMA_PORT=8090
KEV_PORT=8009
PARAKEET_PORT=8010
BREEZE_PORT=8080

# Gemma 4 12B instruct, pulled by llama-server on first start. On an 8 GB GPU use the UD-Q3_K_XL quant (about 6 GB).
GEMMA_MODEL="${GEMMA_MODEL:-unsloth/gemma-4-12b-it-GGUF:Q4_K_M}"
# Kev models for kev serve --run (LoRA adapters; kev pulls the Qwen3.5 base model too). KEV_MODEL overrides both.
KEV_MODEL_FULL="${KEV_MODEL:-jaredpalmer/kev-4b}"
KEV_MODEL_LIGHT="${KEV_MODEL:-jaredpalmer/kev-0.8b}"
# Breeze GGUF files under MODELS_DIR, from the HoppouAI/Breeze-TTS-2.cpp model repo on Hugging Face.
BREEZE_Q8_FILE="breeze-tts-2-q8_0.gguf"
BREEZE_Q4_FILE="breeze-tts-2-q4_k.gguf"
