# Model providers

A **provider** is a model server the framework talks to over HTTP on the local machine. The framework has four
provider kinds. Each kind serves one or more features:

| Kind | Adapter name | Server in the demo | Used for |
| --- | --- | --- | --- |
| `GENERATE` | `openai_chat` | llama.cpp `llama-server` with Gemma 4 12B | NPC lines (through the C2 line generator) |
| `CHOOSE` | `kev_systemone` | Kev-4B `kev.serve` | intent choice and presentation choice (C3b) |
| `TRANSCRIBE` | `openai_transcribe` | Parakeet wrapper (C6) | speech in (C3c, C4) |
| `SPEAK` | `breeze_speech` | `breeze-server` | speech out (C3c, C4) |

Only the `GENERATE` adapter exists in C3a. The other kinds are added by later parts of this batch.

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
