# CakeWorks demo

## What you get

- Walk the ship with WASD or the arrow keys.
- Talk to the crew: hold **V** to speak, or type into the box and press **Enter**. **F3** shows the debug overlay.
- Seven NPCs answer with subtitles and voices, and rumours spread between them while the day runs.
- The provider panel shows which models answer. A model that is down shows as down, and the NPC falls back to
  keyword replies, so the demo still runs.

## Hardware and profiles

| Profile | Dialogue (Gemma / Kev) | Speech in (Parakeet) | Speech out (Breeze) | Approx. GPU memory |
| --- | --- | --- | --- | --- |
| `full` | Gemma 4 12B Q4_K_M (about 8 GB) / Kev-4B (about 9-10 GB) | GPU, about 2 GB (or CPU) | Breeze q8_0 (about 4.3 GB) | 24 GB or more |
| `light` (default) | Gemma 4 12B Q4_K_M / Kev-0.8B | CPU | Breeze q4_k (about 3.3 GB) | about 12-16 GB |
| `text_only` | Gemma 4 12B or any OpenAI-compatible server / Kev or keyword fallback | off | off | about 8 GB |

`light` is the default. It fits a single 16 GB NVIDIA card. The memory figures are estimates; check them on your machine.

## Quick start (Linux or macOS)

1. From the repository root, sync the example: `bash tools/ci/sync_example.sh`.
2. Prepare the models: `examples/cakeworks/servers/get_models.sh`. Set `BREEZE_Q8_URL` and `BREEZE_Q4_URL` to the
   Hugging Face file URLs first, or Breeze is skipped (see "Breeze" below). Model IDs and file names are checked on
   Hugging Face, not in this repository: **check on Hugging Face** before you run anything.
3. Start the servers: `examples/cakeworks/servers/start_all.sh --profile light`. It waits for each server to answer.
4. Run the smoke check. Every line must say OK:

   ```bash
   godot --headless --path examples/cakeworks -s res://addons/npcf/tools/npcf_cli.gd -- smoke --set res://demo/profiles/light.tres --manifest res://packs/cw/pack.tres --scenario res://packs/cw/scenarios/demo.tres --npc cw.mira --allow-non-commercial
   ```

5. Open `examples/cakeworks` in Godot 4.7 and run the demo with `--allow-non-commercial` in Project > Run arguments.
   Or from the command line: `godot --path examples/cakeworks -- --profile=light --allow-non-commercial`.
6. When you are done: `examples/cakeworks/servers/stop_all.sh`.

## Windows

Use the PowerShell scripts in the same folder, with the same steps:

1. `servers\get_models.ps1` (set `$env:BREEZE_Q8_URL` and `$env:BREEZE_Q4_URL` first, as above).
2. `servers\start_all.ps1 -Profile light`.
3. The smoke command from step 4 above.
4. Run the demo as in step 5.
5. `servers\stop_all.ps1`.

The PowerShell scripts have not been run on Windows yet. Report any problem with them.

## Text only

Use no speech servers at all: `servers/start_all.sh --profile text_only`, then run with `--profile=text_only`.
The demo then needs no Parakeet and no Breeze, and no microphone.

## Running servers by hand

Each server has its own script, with its own flags:

- `start_gemma.sh [--cpu]`: llama-server on port 8090. `--cpu` is slow but runs without a GPU.
- `start_kev.sh [--light]`: `kev serve` on port 8009. If `KEV_API_KEY` is set, the server requires it.
- `start_parakeet.sh [--cpu]`: our wrapper on port 8010.
- `start_breeze.sh [--light]`: breeze-server on port 8080.

Every server binds to 127.0.0.1. Breeze has no authentication, so do not change that.

## Licences

- **Gemma 4** and **Kev** are Apache-2.0.
- **Speech recognition:** NVIDIA Parakeet TDT 0.6B v2, CC-BY-4.0. The wrapper in `servers/parakeet/server.py` is ours.
- **Breeze TTS 2 weights are non-commercial** (BreezeBlue Research and Non-Commercial License). The demo refuses
  voice output unless you pass `--allow-non-commercial`, and release exports always refuse. Do not ship Breeze in a
  commercial build. See `docs/providers.md` for the gate.

## Breeze

Breeze is built from source (`Breeze-TTS-2.cpp`, Vulkan build, which needs the Vulkan SDK and CMake). Its weights are
not downloaded by a script in this repository. Copy the two GGUF file URLs from Hugging Face and set
`BREEZE_Q8_URL` and `BREEZE_Q4_URL`. The file names `breeze-tts-2-q8_0.gguf` and `breeze-tts-2-q4_k.gguf` are
inferred: **check on Hugging Face**.

## Troubleshooting

- **Use the provider panel colours and the smoke check first.** The smoke check prints one line per model.
- **Gemma replies with no JSON:** set `json_schema` to false on the Gemma provider (`extra.json_schema`).
  Some llama-server builds do not honour JSON schemas.
- **Kev shows "keyword fallback":** the Kev server is down, or its answer is not understood. Check
  `servers/kev.log`.
- **Speech status "cut":** see the Breeze note in `docs/providers.md`. The audio still plays.
- **Mic silent:** enable microphone permission for the OS and for Godot.
- **A server did not start:** read `servers/<name>.log` (and `servers/<name>.err.log` on Windows).
- **Kev still running after stop_all.sh:** `uv` can leave the Python child running. Stop it by hand.

## Check on Hugging Face

These values were inferred when the scripts were written. Confirm each one before the first run:

- `ggml-org/gemma-4-12B-GGUF:Q4_K_M` (in `servers/common.sh` and `servers/start_all.ps1`)
- `jaredpalmer/kev-4b` and `jaredpalmer/kev-0.8b` (the 0.8B ID is inferred)
- `nvidia/parakeet-tdt-0.6b-v2` (in `servers/parakeet/server.py`)
- The Breeze GGUF file names `breeze-tts-2-q8_0.gguf` and `breeze-tts-2-q4_k.gguf`
