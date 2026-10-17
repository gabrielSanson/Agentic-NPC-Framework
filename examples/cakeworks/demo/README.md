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
2. Prepare the models: `examples/cakeworks/servers/get_models.sh --profile light`. With `--profile text_only` it
   prepares only Kev.
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

1. `servers\get_models.ps1 -Profile light`.
2. `servers\start_all.ps1 -Profile light`.
3. The smoke command from step 4 above.
4. Run the demo as in step 5.
5. `servers\stop_all.ps1`.

The PowerShell scripts were checked on Windows 11 with an RTX 5060 (8 GB) in the `text_only` profile.

## Text only

Use no speech servers at all: `servers/start_all.sh --profile text_only`, then run with `--profile=text_only`.
The demo then needs no Parakeet and no Breeze, and no microphone.

On an 8 GB GPU, use the smaller Gemma quant and the small Kev model (Kev runs on the CPU):

```bash
export GEMMA_MODEL=unsloth/gemma-4-12b-it-GGUF:UD-Q3_K_XL KEV_MODEL=jaredpalmer/kev-0.8b
```

In PowerShell: `$env:GEMMA_MODEL="unsloth/gemma-4-12b-it-GGUF:UD-Q3_K_XL"; $env:KEV_MODEL="jaredpalmer/kev-0.8b"`.
Kev-0.8B is often less confident than the dialogue threshold, so the smoke check's intents line can fall back to
keywords.

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

Breeze is built from source (`Breeze-TTS-2.cpp`, Vulkan build, which needs the Vulkan SDK and CMake). `get_models`
downloads `breeze-tts-2-q8_0.gguf` and `breeze-tts-2-q4_k.gguf` from the `HoppouAI/Breeze-TTS-2.cpp` model repo on
Hugging Face. Set `BREEZE_Q8_URL` and `BREEZE_Q4_URL` to download them from somewhere else.

## Troubleshooting

- **Use the provider panel colours and the smoke check first.** The smoke check prints one line per model.
- **Gemma replies are empty:** Gemma 4 thinks by default and puts nothing in the answer. The scripts pass
  `--reasoning-budget 0`; keep it when you start llama-server by hand.
- **Gemma is very slow on an 8 GB GPU:** the model spilled into shared memory. Use the UD-Q3_K_XL quant and one slot
  (`-np 1`), as the scripts do.
- **Gemma replies with no JSON:** set `json_schema` to false on the Gemma provider (`extra.json_schema`).
  Some llama-server builds do not honour JSON schemas.
- **Kev shows "keyword fallback":** the Kev server is down, or its answer is not understood. Check
  `servers/kev.log`.
- **Speech status "cut":** see the Breeze note in `docs/providers.md`. The audio still plays.
- **Mic silent:** enable microphone permission for the OS and for Godot.
- **A server did not start:** read `servers/<name>.log` (and `servers/<name>.err.log` on Windows).
- **Kev still running after stop_all.sh:** `uv` can leave the Python child running. Stop it by hand.
  (`stop_all.ps1` stops child processes too.)

## Model IDs

These were checked on Hugging Face on 2026-10-17:

- `unsloth/gemma-4-12b-it-GGUF` (instruct; `Q4_K_M` about 7.1 GB, `UD-Q3_K_XL` about 6 GB). `GEMMA_MODEL` overrides it.
- `jaredpalmer/kev-4b` and `jaredpalmer/kev-0.8b`: LoRA adapters. Kev also downloads the base model
  (`Qwen/Qwen3.5-4B-Base`, about 9.3 GB, or `Qwen/Qwen3.5-0.8B-Base`, about 1.7 GB). `KEV_MODEL` overrides it.
- `nvidia/parakeet-tdt-0.6b-v2` (about 2.5 GB, in `servers/parakeet/server.py`).
- `HoppouAI/Breeze-TTS-2.cpp`: `breeze-tts-2-q8_0.gguf` and `breeze-tts-2-q4_k.gguf`.
