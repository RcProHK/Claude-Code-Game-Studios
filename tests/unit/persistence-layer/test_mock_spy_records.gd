# MockPersistenceLayer — Story 005 AC-12 / AC-12b Spy Recording Tests
#
# Scope: proves MockPersistenceLayer records every write/delete call into
# attached spy callables, and that `clear_spies()` cleanly disables future
# recording without affecting the underlying data cache.
#
# AC-12 (GDD design/gdd/persistence-layer.md):
#   GIVEN MockPersistenceLayer + `attach_write_spy(write_log.append)` +
#         `attach_delete_spy(delete_log.append)`,
#   WHEN  `write("foo", "bar")` + `write("baz", 42)` + `delete("foo")`,
#   THEN  write_log == [{"key": "foo", "value": "bar"},
#                       {"key": "baz", "value": 42}];
#         delete_log == ["foo"].
#
# AC-12b:
#   GIVEN MockPersistenceLayer with spy + `clear_spies()` called,
#   WHEN  `write("after_clear", 99)`,
#   THEN  spy NOT fired for post-clear write.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 14
extends GutTest


var _mock: MockPersistenceLayer = null
var _write_log: Array = []
var _delete_log: Array = []


func before_each() -> void:
	# Fresh mock + fresh log arrays for full test isolation.
	_mock = MockPersistenceLayer.new()
	_write_log = []
	_delete_log = []


## AC-12: MockPersistenceLayer records write + delete calls in spy logs.
func test_mock_persistence_layer_spy_records_writes_and_deletes() -> void:
	# Arrange
	_mock.attach_write_spy(_write_log.append)
	_mock.attach_delete_spy(_delete_log.append)

	# Act
	_mock.write("foo", "bar")
	_mock.write("baz", 42)
	_mock.delete("foo")

	# Assert
	assert_eq(_write_log.size(), 2, "Two writes must produce two spy entries")
	assert_eq(_write_log[0], {"key": "foo", "value": "bar"})
	assert_eq(_write_log[1], {"key": "baz", "value": 42})
	assert_eq(_delete_log.size(), 1, "One delete must produce one spy entry")
	assert_eq(_delete_log[0], "foo")


## AC-12b: clear_spies() stops all future spy invocations.
func test_mock_persistence_layer_clear_spies_stops_future_recording() -> void:
	# Arrange
	_mock.attach_write_spy(_write_log.append)
	_mock.write("before_clear", 1)

	# Act
	_mock.clear_spies()
	_mock.write("after_clear", 99)

	# Assert
	assert_eq(_write_log.size(), 1, "Only pre-clear write must be logged")
	assert_eq(_write_log[0].get("key"), "before_clear")


## Additional: write() still mutates the data cache even after clear_spies() —
## spy removal must not break the underlying IPersistence contract.
func test_mock_persistence_layer_write_works_after_clear_spies() -> void:
	# Arrange
	_mock.clear_spies()

	# Act
	var ok: bool = _mock.write("key", "val")

	# Assert
	assert_true(ok, "write() must return true even without spies attached")
	assert_eq(_mock.read("key"), "val",
		"Cache must be updated even when no spies are watching")
