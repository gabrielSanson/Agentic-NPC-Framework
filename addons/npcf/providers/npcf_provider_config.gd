@tool
class_name NpcfProviderConfig
extends Resource
## One model server (R13.6). Keys come only from the environment variable named in key_env; the key itself is
## never stored here.

enum Kind { GENERATE, CHOOSE, TRANSCRIBE, SPEAK }
enum License { OPEN, NON_COMMERCIAL }

const DEFAULT_TIMEOUT_MS: Array[int] = [8000, 2000, 10000, 10000]
## What each kind may be used for (use_for values).
const USES: Array[Array] = [[&"lines"], [&"intents", &"presentation"], [&"voice_in"], [&"voice_out"]]

@export var id: StringName = &""
@export var kind: Kind = Kind.GENERATE
## openai_chat, kev_systemone, openai_transcribe or breeze_speech.
@export var adapter: StringName = &""
## http://host:port with an optional path prefix, for example http://127.0.0.1:8080 or https://host/api.
@export var base_url: String = "http://127.0.0.1:8080"
@export var model: String = ""
## Name of the environment variable holding the key (sent as "Authorization: Bearer <key>"). Empty = no key.
@export var key_env: String = ""
## 0 = the kind's default (generate 8000, choose 2000, transcribe 10000, speak 10000).
@export_range(0, 120000) var timeout_ms: int = 0
@export_range(100, 30000) var health_timeout_ms: int = 2000
## How long a provider stays down before the gateway checks it again.
@export_range(1000, 600000) var retry_ms: int = 30000
## Requests waiting behind the one in flight. More are answered &"busy".
@export_range(1, 64) var max_queue: int = 4
@export var license_use: License = License.OPEN
## Which features use this provider (see USES). Empty = the provider is checked but used for nothing.
@export var use_for: Array[StringName] = []
## Adapter-specific settings (documented per adapter in docs/providers.md).
@export var extra: Dictionary[StringName, Variant] = {}


func effective_timeout_ms() -> int:
	return timeout_ms if timeout_ms > 0 else DEFAULT_TIMEOUT_MS[kind]


## Config errors, one sentence each. Empty = valid. Adapter names are checked by the gateway.
func check() -> PackedStringArray:
	var out: PackedStringArray = []
	if id == &"":
		out.append("provider id is empty")
	if NpcfEndpoint.parse(base_url) == null:
		out.append("base_url \"%s\" is not http(s)://host[:port][/path]" % base_url)
	var allowed: Array = USES[kind]
	for use: StringName in use_for:
		if not allowed.has(use):
			out.append("use_for \"%s\" is not allowed for kind %s" % [str(use), Kind.keys()[kind]])
	if key_env != "":
		var env_name: RegEx = RegEx.create_from_string("^[A-Z_][A-Z0-9_]*$")
		if env_name.search(key_env) == null:
			out.append("key_env must be an environment variable name")
	return out
