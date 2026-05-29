# PersistenceLayer — Story 003 AC-03 Cache-Disk Invariant Tests (critical flush)
#
# Scope: critical-flush path (`write(key, val, flush=true)`). Proves Rule 2
# cache-disk invariant: when the critical disk flush fails, the cache is
# wiped to the schema-only baseline (Rule 9), `critical_save_failed` emits
# exactly once with `FLUSH_FAILED`, and `write()` returns false.
#
# AC-03 (GDD design/gdd/persistence-layer.md line 462):
#   GIVEN mock `IPersistence` AND `MockFileAccess.store_string_fail = true`,
#   WHEN  `write("foo", "bar", true)` (flush=true, critical path) executes,
#   THEN  `write()` returns false;
#         `_test_get_cache_snapshot().get("foo") == null` (cache reverted per Rule 9 wipe);
#         `critical_save_failed("FLUSH_FAILED", "")` emit count == 1.
#
# Direct private-state access policy:
#   This suite reads `_cache` and writes `_file_factory` directly via
#   `PersistenceLayer.get(...)` / `PersistenceLayer.set(...)`. This is a
#   deliberate test-only affordance permitted by ADR-0006 Contract 14:
#   tests may inspect underscore-prefixed state to assert invariants
#   ("cache reverted per Rule 9 wipe") without adding production
#   observability hooks. The `_test_get_cache_snapshot()` debug seam
#   referenced in the GDD AC is not yet implemented — when it lands
#   (Story 008+), this suite should migrate to use it.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0003 Save State Strategy, ADR-0006 Contract 4/14
extends GutTest


const CACHE_VAR_NAME: StringName = &"_cache"
const FILE_FACTORY_VAR_NAME: StringName = &"_file_factory"
const DIRTY_VAR_NAME: StringName = &"_dirty"


var _factory: MockFileFactory = null


func before_each() -> void:
	# Arrange (shared): clear cache + reset dirty flag for isolation.
	# ADR-0006 Contract 14 affordance — see file header.
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	PersistenceLayer.set(DIRTY_VAR_NAME, false)

	# Inject a fresh MockFileFactory so disk I/O routes through the mock.
	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)

	# Disconnect any signals from prior tests to prevent GUT watch_signals
	# leakage across the autoload-shared signal emitters.
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)
	for conn in PersistenceLayer.corrupt_save_recovered.get_connections():
		PersistenceLayer.corrupt_save_recovered.disconnect(conn.callable)
	for conn in PersistenceLayer.flush_completed.get_connections():
		PersistenceLayer.flush_completed.disconnect(conn.callable)


func after_each() -> void:
	# Detach the test factory so the next test (or production) doesn't
	# accidentally route through a stale MockFileFactory instance.
	PersistenceLayer.set(FILE_FACTORY_VAR_NAME, null)


# ----------------------------------------------------------------------------
# AC-03 core: critical flush failure triggers Rule 9 wipe + signal
# ----------------------------------------------------------------------------

func test_persistence_layer_critical_write_flush_failure_returns_false() -> void:
	# Arrange — configure the mock to fail every store_string() call.
	_factory.fail_next_store_string = true

	# Act
	var result: bool = PersistenceLayer.write("foo", "bar", true)

	# Assert
	assert_false(result, "write() with flush=true must return false when disk flush fails")


func test_persistence_layer_critical_write_flush_failure_wipes_cache_to_baseline() -> void:
	# Arrange
	_factory.fail_next_store_string = true

	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — Rule 9 wipe replaces cache with { "schema_version": SCHEMA_VERSION }.
	# The original "foo" key MUST NOT survive the wipe.
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	assert_null(cache.get("foo"), "Cache key 'foo' must be wiped after FLUSH_FAILED")
	assert_eq(
		cache.get("schema_version"),
		PersistenceLayer.SCHEMA_VERSION,
		"Wiped cache must contain schema_version baseline"
	)


func test_persistence_layer_critical_write_flush_failure_emits_critical_save_failed_once() -> void:
	# Arrange
	_factory.fail_next_store_string = true
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — exactly one emission with the FLUSH_FAILED error code and empty key
	# (per Rule 9: flush-time corruption has no per-key context).
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 1)
	var params: Array = get_signal_parameters(PersistenceLayer, "critical_save_failed", 0)
	assert_eq(params[0], "FLUSH_FAILED", "error_code must be FLUSH_FAILED")
	assert_eq(params[1], "", "key arg must be empty string for flush-time corruption")


# ----------------------------------------------------------------------------
# AC-15b coupling: corrupt_save_recovered emits BEFORE critical_save_failed
# ----------------------------------------------------------------------------

func test_persistence_layer_critical_write_flush_failure_emits_corrupt_recovered_first() -> void:
	# Arrange
	_factory.fail_next_store_string = true
	var emission_order: Array[String] = []
	PersistenceLayer.corrupt_save_recovered.connect(
		func(_n: int) -> void: emission_order.append("recovered")
	)
	PersistenceLayer.critical_save_failed.connect(
		func(_e: String, _k: String) -> void: emission_order.append("failed")
	)

	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — AC-15b ordering contract: recovered first, then failed.
	assert_eq(emission_order.size(), 2, "Both corrupt signals must fire exactly once")
	assert_eq(emission_order[0], "recovered", "corrupt_save_recovered must emit FIRST")
	assert_eq(emission_order[1], "failed", "critical_save_failed must emit AFTER recovered")


# ----------------------------------------------------------------------------
# Negative control: debounced (flush=false) write does NOT trigger Rule 9
# even when the (future) flush would fail — proves AC-03's note about the
# default debounce path behaving differently.
# ----------------------------------------------------------------------------

func test_persistence_layer_non_critical_write_does_not_trigger_corrupt_on_cache_mutation() -> void:
	# Arrange — store_string would fail IF a flush ran, but write(flush=false)
	# defers to the debounce timer which we never tick in this test.
	_factory.fail_next_store_string = true
	watch_signals(PersistenceLayer)

	# Act
	var result: bool = PersistenceLayer.write("foo", "bar")  # flush=false default

	# Assert — cache mutation succeeded; no corrupt signal fired yet.
	# (When the debounce timer fires later, FLUSH_FAILED WILL trigger —
	# that path is covered by AC-15 row 6, not this test.)
	assert_true(result, "Cache-only write must return true even if a future flush would fail")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 0)
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	assert_eq(cache.get("foo"), "bar", "Cache mutation must succeed on debounced write")


# ----------------------------------------------------------------------------
# Happy path: critical write with successful flush returns true + no corrupt
# ----------------------------------------------------------------------------

func test_persistence_layer_critical_write_flush_success_returns_true_no_corrupt() -> void:
	# Arrange — default factory state: store_string succeeds.
	watch_signals(PersistenceLayer)

	# Act
	var result: bool = PersistenceLayer.write("foo", "bar", true)

	# Assert
	assert_true(result, "Successful critical flush must return true")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 0)
	assert_signal_emit_count(PersistenceLayer, "corrupt_save_recovered", 0)
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	assert_eq(cache.get("foo"), "bar", "Cache key preserved on successful critical flush")
