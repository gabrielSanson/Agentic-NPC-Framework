class_name NpcfEndpoint
extends RefCounted
## A parsed model server address, http(s)://host[:port][/prefix]. parse() returns null for anything else.

var host: String = ""
var port: int = 80
var tls: bool = false
## The path before every request, with no trailing slash; "" when none.
var prefix: String = ""


## Parses one URL. Returns null when the scheme, host, port or characters are not allowed.
static func parse(url: String) -> NpcfEndpoint:
	var ep: NpcfEndpoint = NpcfEndpoint.new()
	var rest: String = ""
	if url.begins_with("http://"):
		rest = url.substr(7)
	elif url.begins_with("https://"):
		rest = url.substr(8)
		ep.tls = true
		ep.port = 443
	else:
		return null
	var slash: int = rest.find("/")
	var authority: String = rest if slash < 0 else rest.substr(0, slash)
	var path: String = "" if slash < 0 else rest.substr(slash)
	if authority == "" or authority.contains(" ") or authority.contains("@"):
		return null
	var host_part: String = authority
	var colon: int = authority.rfind(":")
	if colon >= 0:
		host_part = authority.substr(0, colon)
		var port_text: String = authority.substr(colon + 1)
		if not port_text.is_valid_int():
			return null
		var port_number: int = port_text.to_int()
		if port_number < 1 or port_number > 65535:
			return null
		ep.port = port_number
	if host_part == "":
		return null
	ep.host = host_part
	ep.prefix = path.rstrip("/")
	return ep
