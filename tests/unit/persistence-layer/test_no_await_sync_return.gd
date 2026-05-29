# PersistenceLayer — Story 006 AC-13 Sync Signal Emission Tests
#
# Scope: proves `write_completed` emits synchronously within the same call
# stack as `write()` — no await, no deferred signal, no frame boundary
# between write() return and signal emission.
#
# AC-13 (GDD design/gdd/persistence-layer.md Rule 7 + ADR-0006 Contract 11):
#   GIVEN signal counter on `write_completed`,
#   WHEN  `write("foo", "bar")` returns,
#   THEN  `write_completed` emit count == 1 within same call stack;
#         signal args: key=="foo", is_touch==false.
#
# WHY synchronous emission matters:
# ADR-0006 Contract 11 (best-effort IDB fence VS tier): `write()` returns
# immediately — NO await on IDB ack. The write_completed signal is the
# only in-process notification of cache mutation. If emission were deferred
# (e.g. call_deferred), consumer code would read stale state before the
# signal fires, breaking GSM tombstone_write_completed Contract 11 chain
# (design/gdd/persistence-layer.md Rule 7.1 signal split).
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 11 (best-effort IDB fence)
extends GutTest


const CACHE_VAR_NAME: StringName = &"_cache"


func before_each() -> void:
	# Isolation: clear cache + disconnect any prior write_completed listeners.
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)


## AC-13 core: write_completed fires synchronously with correct key and is_touch=false.
## Uses GUT watch_signals (NOT a lambda counter — GDScript lambdas capture locals
## by VALUE, so `var c := 0; connect(func(): c += 1)` never updates the outer `c`).
func test_persistence_layer_write_completed_emits_synchronously_with_correct_args() -> void:
	# Arrange — watch BEFORE the write.
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer.write("foo", "bar")

	# Assert — emit count read immediately after write() returns (same call stack).
	# If emission were async/deferred, the count would be 0 here.
	assert_signal_emit_count(PersistenceLayer, "write_completed", 1,
		"write_completed must emit exactly once per write()")
	var params: Array = get_signal_parameters(PersistenceLayer, "write_completed")
	assert_eq(params[0], "foo", "write_completed key arg must match written key")
	assert_false(params[2], "write_completed is_touch must be false for normal write()")


## AC-13 edge: write(flush=true) emits write_completed exactly once (NOT twice —
## critical-flush path must not double-emit the signal).
func test_persistence_layer_critical_write_emits_write_completed_exactly_once() -> void:
	# Arrange
	watch_signals(PersistenceLayer)

	# Act — critical path (flush=true) via MockFileFactory to avoid real disk I/O
	var factory: MockFileFactory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(factory)
	PersistenceLayer.write("foo", "bar", true)
	PersistenceLayer.set(&"_file_factory", null)  # detach mock

	# Assert
	assert_signal_emit_count(PersistenceLayer, "write_completed", 1,
		"write(flush=true) must emit write_completed exactly once")


## Additional: write_completed latency_ms is non-negative integer.
func test_persistence_layer_write_completed_latency_ms_is_non_negative_int() -> void:
	# Arrange
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer.write("key", "value")

	# Assert
	var params: Array = get_signal_parameters(PersistenceLayer, "write_completed")
	var latency_ms: Variant = params[1]
	assert_true(latency_ms is int, "latency_ms must be int type")
	assert_gte(latency_ms, 0, "latency_ms must be non-negative")
