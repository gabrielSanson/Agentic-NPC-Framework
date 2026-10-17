#!/usr/bin/env bash
# Prepares everything the model servers need under MODELS_DIR (default $HOME/npcf-models). Each step is skipped
# when its files already exist. Gemma and Parakeet download their weights on first start, which this script does not
# do. Breeze weights come from the HoppouAI/Breeze-TTS-2.cpp model repo; BREEZE_Q8_URL and BREEZE_Q4_URL override them.
# text_only prepares only Kev (no Parakeet packages, no Breeze build or weights).
# Usage: get_models.sh [--profile light|full|text_only]     (default: light)
set -euo pipefail
source "$(dirname "$0")/common.sh"

PROFILE=light
while [ $# -gt 0 ]; do
	case "$1" in
		--profile) PROFILE="${2:-}"; shift 2 ;;
		--profile=*) PROFILE="${1#--profile=}"; shift ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done
case "$PROFILE" in
	light|full|text_only) ;;
	*) echo "profile must be light, full or text_only" >&2; exit 2 ;;
esac
mkdir -p "$MODELS_DIR"

echo "== Kev: clone and install"
if [ ! -d "$MODELS_DIR/kev" ]; then
	git clone https://github.com/jaredpalmer/kev "$MODELS_DIR/kev"
fi
(cd "$MODELS_DIR/kev" && uv sync --extra serve)

if [ "$PROFILE" = text_only ]; then
	echo "== Done (text_only). Gemma downloads on first start through llama-server -hf."
	exit 0
fi

echo "== Parakeet: virtual environment and packages (weights download on first start, about 2.4 GB)"
if [ ! -x "$MODELS_DIR/parakeet-venv/bin/python" ]; then
	python3 -m venv "$MODELS_DIR/parakeet-venv"
fi
"$MODELS_DIR/parakeet-venv/bin/python" -m pip install -r "$SERVERS_DIR/parakeet/requirements.txt"

echo "== Breeze: source and build"
if [ ! -d "$MODELS_DIR/Breeze-TTS-2.cpp" ]; then
	git clone https://github.com/HoppouAI/Breeze-TTS-2.cpp "$MODELS_DIR/Breeze-TTS-2.cpp"
fi
if [ ! -x "$MODELS_DIR/Breeze-TTS-2.cpp/build/breeze-server" ]; then
	cmake -S "$MODELS_DIR/Breeze-TTS-2.cpp" -B "$MODELS_DIR/Breeze-TTS-2.cpp/build" -DGGML_VULKAN=ON
	cmake --build "$MODELS_DIR/Breeze-TTS-2.cpp/build" -j
fi

echo "== Breeze: GGUF weights (non-commercial license, see demo/README.md)"
fetch_gguf() { # file url
	local file="$MODELS_DIR/$1"
	if [ -f "$file" ]; then
		echo "exists: $file"
	elif [ -z "$2" ]; then
		echo "skipped: $1 (set the URL variable to the Hugging Face file URL to download it)" >&2
	else
		curl -L --fail -C - -o "$file" "$2"
	fi
}
fetch_gguf "$BREEZE_Q8_FILE" "${BREEZE_Q8_URL:-https://huggingface.co/HoppouAI/Breeze-TTS-2.cpp/resolve/main/$BREEZE_Q8_FILE}"
fetch_gguf "$BREEZE_Q4_FILE" "${BREEZE_Q4_URL:-https://huggingface.co/HoppouAI/Breeze-TTS-2.cpp/resolve/main/$BREEZE_Q4_FILE}"

echo "== Done. Gemma downloads on first start through llama-server -hf."
