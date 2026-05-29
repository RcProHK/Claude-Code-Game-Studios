# PersistenceLayer — Story 008 AC-09 Migration Step Timeout Tests
#
# Scope: ADR-0006 Contract 10 per-step timeout. A single N→N+1 step that
# exceeds `MIGRATION_BUDGET_MS` (150ms) is treated as a runaway migration
# (likely O(n) over a pathological cache). The chain MUST:
#   * stop after the offending step,
#   * revert `_cache` to the pre-step snapshot (AC-10 atomic-or-fail-loud),
#   * emit exactly one `critical_save_failed("MIGRATION_TIMEOUT",
#     "step_<from>_to_<to>")`,
#   * return false from `migrate()`,
#   * leave the cache wiped to schema-only baseline (Rule 9 corrupt path —
#     applies AFTER the revert to pre-step state, so the final cache is the
#     baseline, not the pre-step snapshot).
#
# AC-09 (GDD design/gdd/persistence-layer.md AC-09):
#   GIVEN a mock step taking 200ms (> MIGRATION_BUDGET_MS = 150ms),
#   WHEN  `migrate(0, 1)` runs,
#   THEN  `migrate()` returns false;
#         critical_save_failed("MIGRATION_TIMEOUT", "step_0_to_1") emitted;
#         substate == Corrupt (cache wiped to schema-only baseline).
#
# Timing seam: `_migration_step_delay_ms` (test-only field on
# PersistenceLayer) drives `_migrate_one_step` to block via OS.delay_msec()
# in debug builds. This is the GDScript stand-in for an IClock injection
# (deferred to a later story).
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0003 Save State Strategy, ADR-0006 Contract 4/10/14
extends GutTest


const CACHE_VAR_NAME: StringName = &"_cache"
const FILE_FACTORY_VAR_NAME: StringName = &"_file_factory"
const DIRTY_VAR_NAME: StringName = &"_dirty"
const SUPPRESS_VAR_NAME: StringName = &"_suppress_write_completed"
const STEP_DELAY_VAR_NAME: StringName = &"_migration_step_delay_ms"
const STEP_FAIL_VAR_NAME: StringName = &"_migration_step_fail_next"
const STEP_MUTATE_KEY_VAR_NAME: StringName = &"_migration_step_mutate_key"
const STEP_MUTATE_VALUE_VAR_NAME: StringName = &"_migration_step_mutate_value"

## Configured per-step delay (ms). 200 > MIGRATION_BUDGET_MS(150) so the
## first step must trigger the timeout branch.
const OVER_BUDGET_DELAY_MS: int = 200


var _factory: MockFileFactory = null
var _step_signals: Array = []
var _critical_signals: Array = []


func before_each() -> void:
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	PersistenceLayer.set(DIRTY_VAR_NAME, false)
	PersistenceLayer.set(SUPPRESS_VAR_NAME, false)
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, 0)
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, false)
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, null)

	_step_signals = []
	_critical_signals = []

	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)

	for conn in PersistenceLayer.migration_step_completed.get_connections():
		PersistenceLayer.migration_step_completed.disconnect(conn.callable)
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)
	for conn in PersistenceLayer.corrupt_save_recovered.get_connections():
		PersistenceLayer.corrupt_save_recovered.disconnect(conn.callable)
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)
	for conn in PersistenceLayer.flush_completed.get_connections():
		PersistenceLayer.flush_completed.disconnect(conn.callable)


func after_each() -> void:
	PersistenceLayer.set(FILE_FACTORY_VAR_NAME, null)
	PersistenceLayer.set(SUPPRESS_VAR_NAME, false)
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, 0)
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, false)
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, null)


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _record_step(from_version: int, to_version: int, latency_ms: int) -> void:
	_step_signals.append({
		"from": from_version,
		"to": to_version,
		"latency_ms": latency_ms,
	})


func _record_critical(error_code: String, key: String) -> void:
	_critical_signals.append({
		"error_code": error_code,
		"key": key,
	})


# ----------------------------------------------------------------------------
# AC-09 core: 200ms step trips MIGRATION_TIMEOUT
# ----------------------------------------------------------------------------

func test_persistence_layer_migrate_over_budget_step_returns_false() -> void:
	# Arrange — single step configured to block for 200ms (> 150ms budget).
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, OVER_BUDGET_DELAY_MS)

	# Act
	var ok: bool = PersistenceLayer.migrate(0, 1)

	# Assert
	assert_false(
		ok,
		"migrate() must return false when a step exceeds MIGRATION_BUDGET_MS"
	)


func test_persistence_layer_migrate_over_budget_emits_no_step_completed_signal() -> void:
	# Arrange — overly slow step + step recorder.
	#   The over-budget step must NOT emit migration_step_completed —
	#   migrate() detects the timeout AFTER the step body runs but BEFORE
	#   emitting the success signal.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, OVER_BUDGET_DELAY_MS)
	PersistenceLayer.migration_step_completed.connect(_record_step)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — over-budget step is NOT counted as completed.
	assert_eq(
		_step_signals.size(),
		0,
		"an over-budget step must NOT emit migration_step_completed"
	)


func test_persistence_layer_migrate_over_budget_emits_migration_timeout_critical() -> void:
	# Arrange
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, OVER_BUDGET_DELAY_MS)
	PersistenceLayer.critical_save_failed.connect(_record_critical)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — exactly one critical_save_failed with spec'd code + key.
	assert_eq(
		_critical_signals.size(),
		1,
		"critical_save_failed must emit exactly once on MIGRATION_TIMEOUT"
	)
	assert_eq(
		_critical_signals[0]["error_code"],
		"MIGRATION_TIMEOUT",
		"error_code must be 'MIGRATION_TIMEOUT' on an over-budget step"
	)
	assert_eq(
		_critical_signals[0]["key"],
		"step_0_to_1",
		"key must carry the step label 'step_<from>_to_<to>' for diagnostics"
	)


func test_persistence_layer_migrate_over_budget_wipes_cache_to_baseline() -> void:
	# Arrange — seed cache with extra data; after timeout it must be wiped.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.get(CACHE_VAR_NAME)["pre_timeout_canary"] = "should_be_wiped"
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, OVER_BUDGET_DELAY_MS)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — cache is at schema-only baseline (Corrupt substate).
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	assert_false(
		cache.has("pre_timeout_canary"),
		"cache must be wiped to baseline after MIGRATION_TIMEOUT triggers Rule 9"
	)
	assert_eq(
		cache.get("schema_version", -1),
		PersistenceLayer.SCHEMA_VERSION,
		"post-wipe cache must equal {schema_version: SCHEMA_VERSION}"
	)


func test_persistence_layer_migrate_over_budget_clears_suppression_flag() -> void:
	# Arrange
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, OVER_BUDGET_DELAY_MS)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — suppression cleared even on failure path; post-migration
	# writes emit write_completed again.
	assert_false(
		PersistenceLayer.get(SUPPRESS_VAR_NAME),
		"_suppress_write_completed must be cleared on the timeout failure path"
	)

	var post_writes: Array = []
	PersistenceLayer.write_completed.connect(
		func(k: String, _ms: int, _it: bool) -> void:
			post_writes.append(k)
	)
	PersistenceLayer.write("post_timeout_probe", true, false)
	assert_eq(
		post_writes.size(),
		1,
		"normal write() after a failed migrate() must re-emit write_completed"
	)


func test_persistence_layer_migrate_over_budget_emits_corrupt_recovered_before_critical() -> void:
	# Arrange — connect both Rule 9 signals to verify ordering on the
	# timeout path matches the chain-too-long path (AC-15b consistency).
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, OVER_BUDGET_DELAY_MS)
	var event_order: Array[String] = []
	PersistenceLayer.corrupt_save_recovered.connect(
		func(_count: int) -> void:
			event_order.append("corrupt_save_recovered")
	)
	PersistenceLayer.critical_save_failed.connect(
		func(_code: String, _key: String) -> void:
			event_order.append("critical_save_failed")
	)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — Rule 9 ordering preserved on the timeout failure path.
	assert_eq(event_order.size(), 2, "both Rule 9 signals must fire exactly once")
	assert_eq(
		event_order[0],
		"corrupt_save_recovered",
		"corrupt_save_recovered MUST fire before critical_save_failed (AC-15b)"
	)
	assert_eq(event_order[1], "critical_save_failed")
