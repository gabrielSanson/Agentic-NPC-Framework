class_name NpcfHttpCall
extends RefCounted
## One HTTP request, advanced by poll(). Reads the body as it arrives (sized, chunked or until close). on_chunk
## (optional) gets each body piece; on_done gets one NpcfHttpResult, exactly once. A streamed call
## (on_chunk set) does not keep the body in the result.

var done: bool = false

var _spec: NpcfHttpSpec
var _endpoint: NpcfEndpoint
var _on_done: Callable
var _on_chunk: Callable
var _client: HTTPClient = HTTPClient.new()
var _started_ms: int = 0
var _sent: bool = false
var _code: int = 0
var _body: PackedByteArray = PackedByteArray()
## Framing of the reply, read with its code: the Content-Length (-1 when none), chunked coding, and the bytes received.
var _declared: int = -1
var _chunked: bool = false
var _received: int = 0


func _init(spec: NpcfHttpSpec, endpoint: NpcfEndpoint, on_done: Callable, on_chunk: Callable = Callable()) -> void:
	_spec = spec
	_endpoint = endpoint
	_on_done = on_done
	_on_chunk = on_chunk


func start(now_ms: int) -> void:
	_started_ms = now_ms
	var tls: TLSOptions = TLSOptions.client() if _endpoint.tls else null
	if _client.connect_to_host(_endpoint.host, _endpoint.port, tls) != OK:
		_finish(&"refused", now_ms)


func poll(now_ms: int) -> void:
	if done:
		return
	if now_ms - _started_ms > _spec.timeout_ms:
		_finish(&"timeout", now_ms)
		return
	_client.poll()
	var st: HTTPClient.Status = _client.get_status()
	if _sent and _code == 0 and _client.has_response():
		_code = _client.get_response_code()
		_read_framing()
	match st:
		HTTPClient.STATUS_CONNECTED:
			if not _sent:
				_sent = true
				var path: String = _endpoint.prefix + _spec.path
				if _client.request_raw(_spec.method, path, _spec.headers, _spec.body) != OK:
					_finish(&"http", now_ms)
			elif _code != 0:
				_finish_reply(true, now_ms)
		HTTPClient.STATUS_BODY:
			var piece: PackedByteArray = _client.read_response_body_chunk()
			if not piece.is_empty():
				_received += piece.size()
				if _on_chunk.is_valid():
					_on_chunk.call(piece)
				else:
					_body.append_array(piece)
		HTTPClient.STATUS_DISCONNECTED:
			if not _sent:
				_finish(&"refused", now_ms)
			elif _code != 0:
				_finish_reply(false, now_ms)
			else:
				_finish(&"http", now_ms)
		HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT:
			_finish(&"refused", now_ms)
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			# A server that closes after a full reply ends here too (Godot reports the close as a connection error),
			# so a reply whose code was already read is judged by that code.
			if not _sent:
				_finish(&"refused", now_ms)
			elif _code != 0:
				_finish_reply(false, now_ms)
			else:
				_finish(&"http", now_ms)


## Ends the call without calling back (used when the gateway closes; it calls back itself).
func cancel() -> void:
	done = true
	_client.close()


## Reads the Content-Length and the chunked flag once the reply's head is in.
func _read_framing() -> void:
	_chunked = _client.is_response_chunked()
	var headers: Dictionary = _client.get_response_headers_as_dictionary()
	for key: Variant in headers:
		if str(key).to_lower() == "content-length":
			_declared = int(str(headers[key]))


## Ends a reply that has a code. A 2xx reply is ok only when the whole body arrived: a Content-Length the body fell
## short of, or a chunked body that ended without its last chunk (clean_end false), makes it http. A close-delimited
## body has no length to check, so its close is the end.
func _finish_reply(clean_end: bool, now_ms: int) -> void:
	var ok: bool = _code >= 200 and _code < 300
	if ok and _declared >= 0 and _received < _declared:
		ok = false
	if ok and _chunked and not clean_end:
		ok = false
	_finish(&"ok" if ok else &"http", now_ms)


func _finish(status: StringName, now_ms: int) -> void:
	if done:
		return
	done = true
	_client.close()
	_on_done.call(NpcfHttpResult.make(status, _code, _body, now_ms - _started_ms))
