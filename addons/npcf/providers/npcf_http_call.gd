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
	match st:
		HTTPClient.STATUS_CONNECTED:
			if not _sent:
				_sent = true
				var path: String = _endpoint.prefix + _spec.path
				if _client.request_raw(_spec.method, path, _spec.headers, _spec.body) != OK:
					_finish(&"http", now_ms)
			elif _code != 0:
				_finish(&"ok" if _code >= 200 and _code < 300 else &"http", now_ms)
		HTTPClient.STATUS_BODY:
			var piece: PackedByteArray = _client.read_response_body_chunk()
			if not piece.is_empty():
				if _on_chunk.is_valid():
					_on_chunk.call(piece)
				else:
					_body.append_array(piece)
		HTTPClient.STATUS_DISCONNECTED:
			if not _sent:
				_finish(&"refused", now_ms)
			elif _code != 0:
				_finish(&"ok" if _code >= 200 and _code < 300 else &"http", now_ms)
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
				_finish(&"ok" if _code >= 200 and _code < 300 else &"http", now_ms)
			else:
				_finish(&"http", now_ms)


## Ends the call without calling back (used when the gateway closes; it calls back itself).
func cancel() -> void:
	done = true
	_client.close()


func _finish(status: StringName, now_ms: int) -> void:
	if done:
		return
	done = true
	_client.close()
	_on_done.call(NpcfHttpResult.make(status, _code, _body, now_ms - _started_ms))
