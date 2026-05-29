# PersistenceLayer — Story 009 AC-16 Corrupt Sticky Single-Emit Tests
#
# Proves Corrupt substate is sticky (no auto-recovery) and critical_save_failed
# emits exactly once even when 100 subsequent write() calls are made.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 11 (sticky corrupt path)
extends GutTest


const SUBSTATE_VAR_NAME: StringName = &"_substate"
const CACHE_VAR_NAME: StringName = &"_cache"

var _factory: MockFileFactory


func before_each() -> void:
	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	PersistenceLayer.set(&"_loaded_file_bytes", 0)
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)
	for conn in PersistenceLayer.corrupt_save_recovered.get_connections():
		PersistenceLayer.corrupt_save_recovered.disconnect(conn.callable)
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)


func after_each() -> void:
	PersistenceLayer.set(&"_file_factory", null)
	PersistenceLayer.set(SUBSTATE_VAR_NAME, PersistenceLayer.Substate.READY)


func _enter_corrupt_state() -> void:
	PersistenceLayer.set(SUBSTATE_VAR_NAME, PersistenceLayer.Substate.INITIALISING)
	PersistenceLayer._trigger_corrupt("FLUSH_FAILED", "")
	assert_eq(PersistenceLayer._test_get_substate(), "CORRUPT")


## AC-16 core: 100 writes succeed (cache mutation) in Corrupt, no re-emit.
func test_corrupt_sticky_100_writes_all_succeed_no_re_emit() -> void:
	# Arrange
	_enter_corrupt_state()
	var critical_count: int = 0
	PersistenceLayer.critical_save_failed.connect(func(_e, _k) -> void: critical_count += 1)
	watch_signals(PersistenceLayer)

	# Act
	for i in range(100):
		var result: bool = PersistenceLayer.write("key_%d" % i, i)
		assert_true(result, "write() must return true in Corrupt (cache mutation OK)")

	# Assert — signal NOT re-emitted after initial trigger
	assert_eq(critical_count, 0,
		"critical_save_failed must NOT re-emit during 100 subsequent writes in Corrupt")


## AC-16: cache is mutated by writes in Corrupt (data accessible).
func test_corrupt_sticky_writes_update_cache() -> void:
	# Arrange
	_enter_corrupt_state()

	# Act
	PersistenceLayer.write("test_key", "test_value")

	# Assert — cache mutation happened despite Corrupt state
	assert_eq(PersistenceLayer.read("test_key"), "test_value",
		"Cache must be updated by write() in Corrupt state")


## AC-16: Corrupt is sticky — re-calling _trigger_corrupt does nothing.
func test_corrupt_sticky_retrigger_does_nothing() -> void:
	# Arrange
	_enter_corrupt_state()
	var critical_count: int = 0
	PersistenceLayer.critical_save_failed.connect(func(_e, _k) -> void: critical_count += 1)

	# Act — re-trigger corrupt (should be no-op)
	PersistenceLayer._trigger_corrupt("FLUSH_FAILED", "")
	PersistenceLayer._trigger_corrupt("INVALID_JSON", "")

	# Assert — still no new emissions
	assert_eq(critical_count, 0, "Re-triggering Corrupt must be a no-op")
	assert_eq(PersistenceLayer._test_get_substate(), "CORRUPT",
		"Substate must still be CORRUPT after re-trigger attempt")
