class_name ProviderFixture
extends RefCounted
## Helpers for provider tests: a pump that drives a fake server and a gateway together, and a chat reply builder.

const VALID_LINE: String = '{"line":"Hi there, friend.","cited_facts":[],"action":null}'


## Polls server and gateway until cond is true or max_ms passes. Returns cond's last value.
static func pump(server: FakeHttpServer, gw: NpcfProviderGateway, cond: Callable, max_ms: int = 3000) -> bool:
	var deadline: int = Time.get_ticks_msec() + max_ms
	var met: bool = cond.call()
	while not met and Time.get_ticks_msec() < deadline:
		server.poll()
		gw.poll()
		OS.delay_msec(1)
		met = cond.call()
	return met


## Polls server and gateway for exactly ms milliseconds (used to show that nothing else happens).
static func idle(server: FakeHttpServer, gw: NpcfProviderGateway, ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		server.poll()
		gw.poll()
		OS.delay_msec(1)


## An OpenAI-style chat completion body whose only choice holds `content`.
static func chat_body(content: String) -> Dictionary:
	return {"choices": [{"message": {"content": content}}]}


## A provider config for an openai_chat server at base_url, using it for lines.
static func chat_config(id: StringName, base_url: String) -> NpcfProviderConfig:
	var cfg: NpcfProviderConfig = NpcfProviderConfig.new()
	cfg.id = id
	cfg.kind = NpcfProviderConfig.Kind.GENERATE
	cfg.adapter = &"openai_chat"
	cfg.base_url = base_url
	cfg.use_for = [&"lines"]
	return cfg
