# Model providers

A **provider** is a model server the framework talks to over HTTP on the local machine. The framework has four
provider kinds. Each kind serves one or more features:

| Kind | Adapter name | Server in the demo | Used for |
| --- | --- | --- | --- |
| `GENERATE` | `openai_chat` | llama.cpp `llama-server` with Gemma 4 12B | NPC lines (through the C2 line generator) |
| `CHOOSE` | `kev_systemone` | Kev-4B `kev.serve` | intent choice and presentation choice (C3b) |
| `TRANSCRIBE` | `openai_transcribe` | Parakeet wrapper (C6) | speech in (C3c, C4) |
| `SPEAK` | `breeze_speech` | `breeze-server` | speech out (C3c, C4) |

The `GENERATE` adapter exists from C3a, the `CHOOSE` adapter from C3b, and the `TRANSCRIBE` and `SPEAK` adapters from C3c.

## Set file and project setting

Providers live in an `NpcfProviderSet` resource (a list of `NpcfProviderConfig` entries, for example one set per
hardware profile). The project setting `npcf/providers/set` names the set to load when the runtime starts. Without
the setting, the runtime runs with no providers, and every feature uses its authored fallback.

Call `NpcfRuntime.use_providers(set)` to load a set from code. The first provider with `lines` in `use_for` becomes the
line generator. Each provider's state is reported by the runtime's `provider_status_changed` signal.

## Fields of `NpcfProviderConfig`

| Field | Meaning |
| --- | --- |
| `id` | Name of the provider. Must not be empty and must be unique in the set. |
| `kind` | `GENERATE`, `CHOOSE`, `TRANSCRIBE` or `SPEAK`. |
| `adapter` | The adapter for the kind: `openai_chat` for `GENERATE`. A mismatch is refused. |
| `base_url` | `http://host:port` with an optional path prefix, for example `http://127.0.0.1:8080` or `https://host/api`. |
| `model` | Model name sent with each request. Empty means none is sent (llama-server ignores it). |
| `key_env` | Name of the environment variable that holds the API key. The key is sent as `Authorization: Bearer <key>`. Empty means no key. |
| `timeout_ms` | Timeout for one request. `0` uses the kind's default: 8000 (GENERATE), 2000 (CHOOSE), 10000 (TRANSCRIBE, SPEAK). |
| `health_timeout_ms` | Timeout for the health check (100 to 30000). |
| `retry_ms` | How long a down provider waits before the gateway checks it again (1000 to 600000). |
| `max_queue` | Requests waiting behind the one in flight (1 to 64). More are answered `busy`. |
| `license_use` | `OPEN` or `NON_COMMERCIAL`. The non-commercial gate is added in C3c. |
| `use_for` | Features that use this provider. Allowed values depend on the kind: `lines` (GENERATE), `intents` and `presentation` (CHOOSE), `voice_in` (TRANSCRIBE), `voice_out` (SPEAK). |
| `extra` | Adapter-specific settings. For `openai_chat`: `json_schema` (default `true`). Set it to `false` when the server does not support JSON schema output. |

The key itself is never stored in a set file. Only the variable name goes in `key_env`. Property names that contain
`api_key`, `token` or `secret` are rejected by CI, so the field is called `key_env`.

## Example for llama-server

Start the server with:

```
llama-server -m gemma-4-12B-Q4_K_M.gguf --port 8080 --jinja
```

`--jinja` is needed for Gemma's chat template. Then describe it in a set with `kind = GENERATE`, `adapter =
"openai_chat"`, `base_url = "http://127.0.0.1:8080"`, `use_for = ["lines"]`. Keep `base_url` on 127.0.0.1 unless the
server is reachable only from a trusted network.

## When a provider is down

Nothing waits for a provider. Every feature falls back at once:

- **Lines:** the authored line is used.
- **Intents:** keyword intent classification is used.
- **Presentation:** the rule-based answer is used.
- **Voice:** voice is off (from C3c).

A provider is `checking` while its first health check runs, and `down` after a failed check or request. A refused
connection marks it `down` until the next recheck (`retry_ms`). A provider in `checking` counts as not ready. Failed
requests are not retried. A provider that cannot load its key variable, or whose config is refused (bad URL, unknown
adapter, or a kind mismatch), never receives a request.

The states are `checking`, `ready`, `down` and `refused`. A reason string goes with each one. It never contains a key.

## Checking a set from the command line

```
godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- providers check --set res://providers/demo.tres
```

The command prints one line per provider (`id  KIND  adapter  base_url  state`, plus the reason when there is one)
and waits up to 15 seconds for every health check. It exits 0 when every provider is `ready`, 1 when any is not,
and 2 on bad usage. `--allow-non-commercial` is accepted but has no effect until C3c.

## Core never does HTTP

Code under `addons/npcf/core/` and `addons/npcf/config/` does no HTTP and does not name provider classes. All HTTP
lives in `addons/npcf/providers/` and in the runtime that wires it. CI enforces this rule (`check_boundaries`).
The simulation never waits for a model server, so a slow or missing server never changes the ticks.

## Kev: intents and presentation (C3b)

The `kev_systemone` adapter (kind `CHOOSE`) serves two features. Its `use_for` may list `intents` and `presentation`:

- **Intents.** The first provider with `intents` classifies the player's text. One choice question has the pack's
  intents as its options, with each intent's description as the option's description. The answer is used only when it
  names an intent of the pack; a failure or an unknown option falls back to the keyword classifier.
- **Presentation.** The first provider with `presentation` answers every presentation question of a line in one
  request. An option the provider names that is not one of the question's options gets the rule answer. A newer turn
  replaces a waiting older one, so a slow answer never comes after a newer line.

The request is `POST /v1/systemone` with the `state` text, `model` (default `kev-latest`) and one question of type
`choice` per question, each with `instructions` and `criteria` (option to description). Options keep their authored
order on the wire. The reply's `answers` are read by question id. The chosen option is read from `answer`, `option`
or `choice`, whichever is a non-empty string first. The Kev README names it `choice`. Confidence is `confidence` when
present, else the highest probability, else 1.0. Probabilities that are not numbers are skipped.

`extra.intent_instructions` (a string) replaces the default question for the intent choice:
"Which option best describes what the player means?".

Start the server with `uv run --extra serve python -m kev.serve --run jaredpalmer/kev-4b --port 8009`. On a small GPU,
use Kev-0.8B: `--run jaredpalmer/kev-0.8b`. Leave `model` empty in the provider config, so the request names
`kev-latest`. Kev is open by default on `127.0.0.1`. Set `KEV_API_KEY` on the server and `key_env` in the config to
require a key. The health check is `GET /`: any answer below 500 means the server is up.

## Transcription and speech (C3c)

**Transcribe** (`openai_transcribe`, kind `TRANSCRIBE`, `use_for` = `voice_in`). The wrapper contract is:
- `POST /v1/audio/transcriptions` with a `multipart/form-data` body. Parts, in order: `file` (the audio as a WAV file,
  16 kHz, mono, 16-bit PCM), `model` (only when the config's `model` is set), `response_format` = `json`.
- The reply is JSON with a `text` string. Any other reply, or an empty text, is a failed transcription.
- Health is `GET /health` (`extra.health_path` overrides it). Any answer below 500 means the server is up.
- The runtime call is `Npcf.transcribe(pcm16_mono_16k, on_done)`. `on_done` gets `(text, status)`. The status is
  `&"off"` when no voice_in provider is ready, `&"http"` for an ok reply with no text, else the request's status.

**Speak** (`breeze_speech`, kind `SPEAK`, `use_for` = `voice_out`). The Breeze contract is:
- `POST /v1/audio/speech` with a `multipart/form-data` body. Parts, in order: `text`, `instruction` (only when not
  empty), `voice_id` (only when not empty).
- The reply streams raw mono 16-bit little-endian PCM at 24 kHz, with no header. A WAV header is removed if the server
  sends one. The runtime call is `Npcf.speak(text, instruction, voice_id, on_chunk, on_done)`. `on_chunk` gets whole
  samples (an odd byte waits for the next piece) and `on_done` gets the status (`&"off"` when no voice_out provider is
  ready).
- The timeout covers the whole stream. A long line needs a larger `timeout_ms` in the config.
- A reply that stops before its declared length, or a chunked reply that stops before its last chunk, ends as
  `&"http"`. The chunks already delivered stand; the result claims nothing more.
- Start the server with `breeze-server breeze-tts-2-q8_0.gguf --host 127.0.0.1 --port 8080`. Bind it to `127.0.0.1`.

**The non-commercial gate.** Breeze TTS 2 weights are under a non-commercial license. A provider with
`license_use = NON_COMMERCIAL`, and every `breeze_speech` provider whatever its config says, is refused unless the
project opts in with the project setting `npcf/providers/allow_non_commercial = true`. It is always refused in release
export builds. A refused provider is never health-checked and never sent a request; it stays `refused` with the reason.
The CLI accepts `--allow-non-commercial` for checks. A game that ships needs a different speech provider.


## Smoke check (C6c)

```
godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- smoke --set R --manifest P --scenario S --npc ID \
	[--text T] [--wav PATH] [--seed N] [--allow-non-commercial] [--timeout-ms 20000]
```

It starts the runtime, loads the set and runs these steps against one NPC, printing `OK` or `FAIL` per step:

- `providers`: every provider is `ready` (the reason is shown for any that is not).
- `voice_out`: speaks a fixed sentence. A reply cut short after audio arrived is still OK, with the detail "reported as
  cut" (a chunked close, the open question for Breeze).
- `voice_in`: transcribes `--wav` (16 kHz mono 16-bit PCM), or the speech from `voice_out` when no `--wav` is given.
- `intents`, `presentation`, `lines`: one line of dialogue, checked on its turn record. A keyword fallback fails
  `intents`; an authored line fails `lines`.

A step is skipped (OK, "skipped: no provider") only when no provider in the set has its use. The exit code is 0 when every
step is OK, 1 when one fails, and 2 on bad usage. `--wav` must be 16 kHz mono 16-bit PCM; other WAV files exit 2.
