extends GdUnitTestSuite


func test_toolchain_runs() -> void:
	assert_int(1 + 1).is_equal(2)
