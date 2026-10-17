#!/usr/bin/env bash
# Prepares everything the model servers need under MODELS_DIR (default $HOME/npcf-models). Each step is skipped
# when its files already exist. Gemma and Parakeet download their weights on first start, which this script does not
# do. Breeze needs two GGUF URLs you copy from Hugging Face (BREEZE_Q8_URL and BREEZE_Q4_URL); they are not guessed here.
# Usage: get_models.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"
mkdir -p "$MODELS_DIR"

echo "== Kev: clone and install"
if [ ! -d "$MODELS_DIR/kev" ]; then
	git clone https://github.com/jaredpalmer/kev "$MODELS_DIR/kev"
fi
(cd "$MODELS_DIR/kev" && uv sync --extra serve)

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
fetch_gguf "$BREEZE_Q8_FILE" "${BREEZE_Q8_URL:-}"
fetch_gguf "$BREEZE_Q4_FILE" "${BREEZE_Q4_URL:-}"

echo "== Done. Gemma downloads on first start through llama-server -hf."
