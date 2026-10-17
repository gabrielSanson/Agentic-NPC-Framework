class_name NpcfProviderAdapter
extends RefCounted
## Turns one provider kind's requests into HTTP and back. Stateless. Subclasses add kind-specific build and
## parse functions.


func kind() -> NpcfProviderConfig.Kind:
	return NpcfProviderConfig.Kind.GENERATE


## The request that tells whether the server is up.
func health_spec(cfg: NpcfProviderConfig) -> NpcfHttpSpec:
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.path = "/"
	s.timeout_ms = cfg.health_timeout_ms
	return s


## Default: the server answered with any code below 500 (a 404 still means it is up).
func health_ok(r: NpcfHttpResult) -> bool:
	return (r.status == &"ok" or r.status == &"http") and r.code >= 100 and r.code < 500
