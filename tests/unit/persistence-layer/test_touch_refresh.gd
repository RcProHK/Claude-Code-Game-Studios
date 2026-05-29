# PersistenceLayer — Story 011 AC-17/17b/17c Touch + Delete Tests
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 9 (ITP touch), Contract 11 (critical flush)
extends GutTest


var _factory: MockFileFactory


func before_each() -> void:
	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)
	PersistenceLayer.get(&"_cache").clear()
	PersistenceLayer._test_force_substate(&"READY")
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)
	for conn in PersistenceLayer.delete_completed.get_connections():
		PersistenceLayer.delete_completed.disconnect(conn.callable)
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)


func after_each() -> void:
	PersistenceLayer.set(&"_file_factory", null)


## AC-17: touch() emits write_completed with is_touch=true; cache value unchanged.
func test_touch_emits_write_completed_is_touch_true() -> void:
	# Arrange
	PersistenceLayer.write("foo", "bar")
	watch_signals(PersistenceLayer)

	# Act
	var result: bool = PersistenceLayer.touch("foo")

	# Assert
	assert_true(result, "touch() must return true for existing key")
	assert_eq(PersistenceLayer.read("foo"), "bar", "Cache value must be unchanged after touch")
	assert_signal_emit_count(PersistenceLayer, "write_completed", 1,
		"touch() must emit write_completed exactly once")
	var p = get_signal_parameters(PersistenceLayer, "write_completed", 0)
	assert_eq(p[0], "foo", "write_completed key arg must be 'foo'")
	assert_true(p[2], "write_completed is_touch must be true")


## AC-17b: touch() on nonexistent key returns false; no write_completed emitted.
func test_touch_nonexistent_key_returns_false_no_signal() -> void:
	# Arrange — empty cache
	watch_signals(PersistenceLayer)

	# Act
	var result: bool = PersistenceLayer.touch("nonexistent")

	# Assert
	assert_false(result, "touch() must return false for absent key")
	assert_signal_emit_count(PersistenceLayer, "write_completed", 0,
		"touch() on absent key must emit zero write_completed")


## AC-17c: delete() removes key, emits delete_completed, returns true.
func test_delete_removes_key_and_emits_delete_completed() -> void:
	# Arrange
	PersistenceLayer.write("key", "val")
	watch_signals(PersistenceLayer)

	# Act
	var result: bool = PersistenceLayer.delete("key")

	# Assert
	assert_true(result, "delete() must return true for existing key")
	assert_null(PersistenceLayer.read("key"), "Key must be absent after delete")
	assert_signal_emit_count(PersistenceLayer, "delete_completed", 1)
	var p = get_signal_parameters(PersistenceLayer, "delete_completed", 0)
	assert_eq(p[0], "key")
	assert_gte(p[1], 0, "delete_completed latency_ms must be non-negative")


## Additional: delete() on absent key returns false, no signal.
func test_delete_absent_key_returns_false_no_signal() -> void:
	watch_signals(PersistenceLayer)
	var result: bool = PersistenceLayer.delete("no_such_key")
	assert_false(result)
	assert_signal_emit_count(PersistenceLayer, "delete_completed", 0)
