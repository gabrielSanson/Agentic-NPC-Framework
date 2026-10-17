extends GdUnitTestSuite
## NpcfHttpCall against the fake server (C3a section 2.13): status mapping, bodies, streamed chunks, timeouts and
## refused connections.

var _servers: Array[FakeHttpServer] = []


func after_test() -> void:
	for s: FakeHttpServer in _servers:
		s.stop()
	_servers.clear()


func _server() -> FakeHttpServer:
	var s: FakeHttpServer = FakeHttpServer.new()
	assert_int(s.start()).is_equal(OK)
	_servers.append(s)
	return s


func _endpoint(url: String) -> NpcfEndpoint:
	return NpcfEndpoint.parse(url)


func _spec(method: HTTPClient.Method, path: String, timeout_ms: int = 2000) -> NpcfHttpSpec:
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = method
	s.path = path
	s.timeout_ms = timeout_ms
	return s


func _start(spec: NpcfHttpSpec, endpoint: NpcfEndpoint, got: Array[NpcfHttpResult]) -> NpcfHttpCall:
	var call: NpcfHttpCall = NpcfHttpCall.new(spec, endpoint, func(r: NpcfHttpResult) -> void: got.append(r))
	call.start(Time.get_ticks_msec())
	return call


## Polls the server and the call until the call is done or max_ms passes.
func _drive(server: FakeHttpServer, call: NpcfHttpCall, max_ms: int = 3000) -> void:
	var deadline: int = Time.get_ticks_msec() + max_ms
	while not call.done and Time.get_ticks_msec() < deadline:
		server.poll()
		call.poll(Time.get_ticks_msec())
		OS.delay_msec(1)


## Polls for a fixed time whether or not the call is done (to catch a second callback).
func _spin(server: FakeHttpServer, call: NpcfHttpCall, ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		server.poll()
		call.poll(Time.get_ticks_msec())
		OS.delay_msec(1)


func test_get_with_a_json_body_is_ok() -> void:
	var server: FakeHttpServer = _server()
	server.json_route("GET /x", 200, {"a": 1})
	var got: Array[NpcfHttpResult] = []
	var call: NpcfHttpCall = _start(_spec(HTTPClient.METHOD_GET, "/x"), _endpoint(server.url()), got)
	_drive(server, call)
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0].status)).is_equal("ok")
	assert_int(got[0].code).is_equal(200)
	assert_dict(got[0].json()).is_equal({"a": 1.0})


func test_a_503_is_http_and_keeps_the_body() -> void:
	var server: FakeHttpServer = _server()
	server.json_route("GET /x", 503, {"error": "busy"})
	var got: Array[NpcfHttpResult] = []
	var call: NpcfHttpCall = _start(_spec(HTTPClient.METHOD_GET, "/x"), _endpoint(server.url()), got)
	_drive(server, call)
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0].status)).is_equal("http")
	assert_int(got[0].code).is_equal(503)
	assert_bool(got[0].text().contains("busy")).is_true()


func test_a_missing_route_is_http_404() -> void:
	var server: FakeHttpServer = _server()
	var got: Array[NpcfHttpResult] = []
	var call: NpcfHttpCall = _start(_spec(HTTPClient.METHOD_GET, "/nowhere"), _endpoint(server.url()), got)
	_drive(server, call)
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0].status)).is_equal("http")
	assert_int(got[0].code).is_equal(404)


func test_post_sends_method_path_content_type_and_exact_body_bytes() -> void:
	var server: FakeHttpServer = _server()
	server.json_route("POST /v1/echo", 200, {})
	var body: PackedByteArray = PackedByteArray([0, 255, 13, 10, 13, 10, 65])
	var spec: NpcfHttpSpec = _spec(HTTPClient.METHOD_POST, "/v1/echo")
	spec.headers = PackedStringArray(["Content-Type: application/json"])
	spec.body = body
	var got: Array[NpcfHttpResult] = []
	var call: NpcfHttpCall = _start(spec, _endpoint(server.url()), got)
	_drive(server, call)
	assert_int(server.requests.size()).is_equal(1)
	var seen: FakeHttpServer.Seen = server.requests[0]
	assert_str(seen.method).is_equal("POST")
	assert_str(seen.path).is_equal("/v1/echo")
	assert_str(seen.headers["content-type"]).is_equal("application/json")
	assert_bool(seen.body == body).is_true()


func test_endpoint_prefix_is_added_to_the_path() -> void:
	var server: FakeHttpServer = _server()
	server.json_route("GET /pre/x", 200, {})
	var got: Array[NpcfHttpResult] = []
	var call: NpcfHttpCall = _start(_spec(HTTPClient.METHOD_GET, "/x"), _endpoint(server.url() + "/pre"), got)
	_drive(server, call)
	assert_int(server.requests.size()).is_equal(1)
	assert_str(server.requests[0].path).is_equal("/pre/x")
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0].status)).is_equal("ok")


func test_a_chunked_stream_reaches_on_chunk_before_done() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = FakeHttpServer.Route.new()
	route.chunks.append(PackedByteArray([1, 2]))
	route.chunks.append(PackedByteArray([3]))
	route.chunks.append(PackedByteArray([4, 5, 6]))
	route.chunk_gap_ms = 20
	server.routes["GET /stream"] = route
	var events: Array[String] = []
	var pieces: Array[PackedByteArray] = []
	var got: Array[NpcfHttpResult] = []
	var call: NpcfHttpCall = NpcfHttpCall.new(_spec(HTTPClient.METHOD_GET, "/stream"), _endpoint(server.url()),
			func(r: NpcfHttpResult) -> void:
				events.append("done")
				got.append(r),
			func(piece: PackedByteArray) -> void:
				events.append("chunk")
				pieces.append(piece))
	call.start(Time.get_ticks_msec())
	_drive(server, call)
	var all: PackedByteArray = PackedByteArray()
	for piece: PackedByteArray in pieces:
		all.append_array(piece)
	assert_bool(all == PackedByteArray([1, 2, 3, 4, 5, 6])).is_true()
	assert_bool(pieces.size() >= 2).is_true()
	assert_str(events[0]).is_equal("chunk")
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0].status)).is_equal("ok")
	assert_int(got[0].code).is_equal(200)
	assert_bool(got[0].body.is_empty()).is_true()


func test_a_hanging_route_times_out_once() -> void:
	var server: FakeHttpServer = _server()
	var route: FakeHttpServer.Route = FakeHttpServer.Route.new()
	route.hang = true
	server.routes["GET /hang"] = route
	var got: Array[NpcfHttpResult] = []
	var started: int = Time.get_ticks_msec()
	var call: NpcfHttpCall = _start(_spec(HTTPClient.METHOD_GET, "/hang", 200), _endpoint(server.url()), got)
	_drive(server, call, 2000)
	var elapsed: int = Time.get_ticks_msec() - started
	assert_bool(elapsed < 2000).is_true()
	_spin(server, call, 300)
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0].status)).is_equal("timeout")


func test_a_closed_port_is_refused() -> void:
	var server: FakeHttpServer = _server()
	var port: int = server.port
	server.stop()
	var endpoint: NpcfEndpoint = NpcfEndpoint.parse("http://127.0.0.1:%d" % port)
	var got: Array[NpcfHttpResult] = []
	var call: NpcfHttpCall = _start(_spec(HTTPClient.METHOD_GET, "/x"), endpoint, got)
	_drive(server, call)
	assert_int(got.size()).is_equal(1)
	assert_str(str(got[0].status)).is_equal("refused")
