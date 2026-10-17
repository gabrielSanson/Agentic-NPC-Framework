class_name FakeHttpServer
extends RefCounted
## A tiny HTTP/1.1 server for provider tests. Call poll() often. Routes are keyed "METHOD /path". Each request is
## recorded. One response per connection, then the connection closes.

class Route:
	var code: int = 200
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body: PackedByteArray = PackedByteArray()
	## When set, the body is sent as these pieces (no Content-Length, connection closes at the end).
	var chunks: Array[PackedByteArray] = []
	var chunk_gap_ms: int = 0
	## With chunks: send them with chunked transfer coding (the reply then ends with a zero-size chunk).
	var chunked: bool = false
	## With chunked: close without the zero-size chunk (a reply cut short).
	var cut_short: bool = false
	## With chunks and not chunked: the Content-Length to declare (-1 = none). Set above the bytes sent, it cuts the
	## reply short.
	var declared_length: int = -1
	var delay_ms: int = 0
	## Never answer (for timeouts).
	var hang: bool = false

class Seen:
	var method: String = ""
	var path: String = ""
	## Lowercase header name -> value.
	var headers: Dictionary[String, String] = {}
	var body: PackedByteArray = PackedByteArray()

class _Conn:
	var peer: StreamPeerTCP
	var buf: PackedByteArray = PackedByteArray()
	var seen: Seen = null
	var route: Route = null
	var ready_at_ms: int = 0
	var head_sent: bool = false
	var next_chunk: int = 0
	var finished: bool = false
	## The last chunk (or the close, for a reply without chunked coding) has been sent.
	var terminated: bool = false

var port: int = 0
var routes: Dictionary[String, Route] = {}
var requests: Array[Seen] = []

var _server: TCPServer = TCPServer.new()
var _conns: Array[_Conn] = []


func start() -> Error:
	var err: Error = _server.listen(0, "127.0.0.1")
	port = _server.get_local_port()
	return err


func url() -> String:
	return "http://127.0.0.1:%d" % port


func stop() -> void:
	for c: _Conn in _conns:
		c.peer.disconnect_from_host()
	_conns.clear()
	_server.stop()


func json_route(key: String, code: int, data: Variant) -> Route:
	var r: Route = Route.new()
	r.code = code
	r.body = JSON.stringify(data).to_utf8_buffer()
	routes[key] = r
	return r


func poll() -> void:
	while _server.is_connection_available():
		var c: _Conn = _Conn.new()
		c.peer = _server.take_connection()
		_conns.append(c)
	var now: int = Time.get_ticks_msec()
	for c: _Conn in _conns.duplicate():
		c.peer.poll()
		if c.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_conns.erase(c)
			continue
		var n: int = c.peer.get_available_bytes()
		if n > 0:
			var got: Array = c.peer.get_data(n)
			var data: PackedByteArray = got[1]
			c.buf.append_array(data)
		if c.seen == null:
			_try_parse(c, now)
		if c.seen != null and not c.finished:
			_respond(c, now)
		if c.finished:
			c.peer.disconnect_from_host()
			_conns.erase(c)


func _try_parse(c: _Conn, now: int) -> void:
	var sep: PackedByteArray = "\r\n\r\n".to_utf8_buffer()
	var at: int = _find(c.buf, sep)
	if at < 0:
		return
	var head: String = c.buf.slice(0, at).get_string_from_utf8()
	var lines: PackedStringArray = head.split("\r\n")
	var request_line: PackedStringArray = lines[0].split(" ")
	var seen: Seen = Seen.new()
	if request_line.size() >= 2:
		seen.method = request_line[0]
		seen.path = request_line[1]
	for i: int in range(1, lines.size()):
		var colon: int = lines[i].find(":")
		if colon > 0:
			seen.headers[lines[i].substr(0, colon).strip_edges().to_lower()] = lines[i].substr(colon + 1).strip_edges()
	var body_start: int = at + sep.size()
	var length: int = 0
	if seen.headers.has("content-length"):
		length = int(seen.headers["content-length"])
	if c.buf.size() < body_start + length:
		return
	seen.body = c.buf.slice(body_start, body_start + length)
	c.seen = seen
	requests.append(seen)
	var key: String = "%s %s" % [seen.method, seen.path]
	if routes.has(key):
		c.route = routes[key]
	else:
		c.route = Route.new()
		c.route.code = 404
		c.route.body = PackedByteArray()
	c.ready_at_ms = now + c.route.delay_ms


func _respond(c: _Conn, now: int) -> void:
	var r: Route = c.route
	if r.hang or now < c.ready_at_ms:
		return
	if r.chunks.is_empty():
		var head: String = _status_head(r)
		head += "Content-Length: %d\r\nConnection: close\r\n\r\n" % r.body.size()
		c.peer.put_data(head.to_utf8_buffer())
		c.peer.put_data(r.body)
		c.finished = true
		return
	if not c.head_sent:
		var framing: String = "Connection: close\r\n"
		if r.chunked:
			# A complete chunked reply keeps the connection open, as a keep-alive server does; the client closes it.
			framing = "Transfer-Encoding: chunked\r\n" + ("Connection: close\r\n" if r.cut_short else "")
		elif r.declared_length >= 0:
			framing = ("Content-Length: %d\r\n" % r.declared_length) + framing
		c.peer.put_data((_status_head(r) + framing + "\r\n").to_utf8_buffer())
		c.head_sent = true
		c.ready_at_ms = now + r.chunk_gap_ms
		return
	if c.next_chunk >= r.chunks.size():
		if c.terminated:
			return
		c.terminated = true
		if r.chunked and not r.cut_short:
			c.peer.put_data("0\r\n\r\n".to_utf8_buffer())
		else:
			c.finished = true
		return
	var piece: PackedByteArray = r.chunks[c.next_chunk]
	if r.chunked:
		c.peer.put_data(("%x\r\n" % piece.size()).to_utf8_buffer())
		c.peer.put_data(piece)
		c.peer.put_data("\r\n".to_utf8_buffer())
	else:
		c.peer.put_data(piece)
	c.next_chunk += 1
	c.ready_at_ms = now + r.chunk_gap_ms


func _status_head(r: Route) -> String:
	var head: String = "HTTP/1.1 %d %s\r\n" % [r.code, _reason(r.code)]
	for h: String in r.headers:
		head += h + "\r\n"
	return head


func _reason(code: int) -> String:
	match code:
		200:
			return "OK"
		404:
			return "Not Found"
		500:
			return "Internal Server Error"
		503:
			return "Service Unavailable"
	return "Status"


func _find(haystack: PackedByteArray, needle: PackedByteArray) -> int:
	var last: int = haystack.size() - needle.size()
	for i: int in range(0, last + 1):
		var hit: bool = true
		for j: int in needle.size():
			if haystack[i + j] != needle[j]:
				hit = false
				break
		if hit:
			return i
	return -1
