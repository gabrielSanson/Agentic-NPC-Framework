extends GdUnitTestSuite
## NpcfEndpoint.parse: each URL gives host, port, tls and prefix, or null (C3a section 2.13).


func _expect(url: String, host: String, port: int, tls: bool, prefix: String) -> void:
	var ep: NpcfEndpoint = NpcfEndpoint.parse(url)
	assert_object(ep).is_not_null()
	if ep == null:
		return
	assert_str(ep.host).is_equal(host)
	assert_int(ep.port).is_equal(port)
	assert_bool(ep.tls).is_equal(tls)
	assert_str(ep.prefix).is_equal(prefix)


func _expect_null(url: String) -> void:
	assert_object(NpcfEndpoint.parse(url)).is_null()


func test_valid_urls_give_host_port_tls_and_prefix() -> void:
	_expect("http://127.0.0.1:8080", "127.0.0.1", 8080, false, "")
	_expect("http://localhost", "localhost", 80, false, "")
	_expect("https://example.org/api/", "example.org", 443, true, "/api")
	_expect("http://h:9/a/b", "h", 9, false, "/a/b")


func test_invalid_urls_give_null() -> void:
	_expect_null("ftp://h")
	_expect_null("http://")
	_expect_null("http://h:0")
	_expect_null("http://h:70000")
	_expect_null("127.0.0.1:8080")
	_expect_null("http://us er@h")
