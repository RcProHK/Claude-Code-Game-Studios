# PersistenceLayer — Story 008 AC-08 Migration Chain Too Long Tests
#
# Scope: ADR-0006 Contract 10 fail-fast pre-check. A migration chain whose
# length exceeds `MAX_MIGRATION_CHAIN_LENGTH` (6) is treated as a structural
# defect, NOT a recoverable runtime condition. The chain MUST short-circuit
# BEFORE any step runs:
#   * zero `migration_step_completed` emits,
#   * exactly one `critical_save_failed("MIGRATION_CHAIN_TOO_LONG", "")`,
#   * `migrate()` returns false,
#   * `_cache` is wiped to the schema-only baseline (Rule 9 corrupt path —
#     verified through the Rule 9 wipe contract, which `_trigger_corrupt`
#     unconditionally runs).
#
# AC-08 (GDD design/gdd/persistence-layer.md AC-08):
#   GIVEN `schema_version_override=11` (gap = 11 > 6),
#   WHEN  `migrate(0, 11)` runs,
#   THEN  fail-fast: 0 step signals,
#         critical_save_failed("MIGRATION_CHAIN_TOO_LONG", "") emitted once,
#         substate = Corrupt (≡ cache wiped to schema-only baseline).
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


var _factory: MockFileFactory = null
var _step_signals: Array = []
var _critical_signals: Array = []
var _corrupt_recovered_signals: Array = []


func before_each() -> void:
	# Arrange (shared): clear cache + reset dirty flag for isolation.
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	PersistenceLayer.set(DIRTY_VAR_NAME, false)
	PersistenceLayer.set(SUPPRESS_VAR_NAME, false)
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, 0)
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, false)
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, null)
	# Clear any sticky CORRUPT substate leaked from boot (a stale user://state.json
	# loaded during _ready) or a prior test — _trigger_corrupt() early-returns when
	# already CORRUPT, which would suppress this test's expected corrupt emission.
	PersistenceLayer._test_force_substate(&"READY")

	_step_signals = []
	_critical_signals = []
	_corrupt_recovered_signals = []

	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)

	# Disconnect prior listeners to keep emit counts clean.
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


func _record_corrupt_recovered(wiped_byte_count: int) -> void:
	_corrupt_recovered_signals.append({
		"wiped_byte_count": wiped_byte_count,
	})


# ----------------------------------------------------------------------------
# AC-08 core: chain length > 6 fails fast with MIGRATION_CHAIN_TOO_LONG
# ----------------------------------------------------------------------------

func test_persistence_layer_migrate_0_to_11_returns_false() -> void:
	# Arrange — schema 0 baseline (cache contents irrelevant for the
	# pre-check; populated only to prove the wipe path runs).
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.get(CACHE_VAR_NAME)["pre_check_canary"] = "should_be_wiped"

	# Act
	var ok: bool = PersistenceLayer.migrate(0, 11)

	# Assert
	assert_false(
		ok,
		"migrate(0, 11) must return false — chain length 11 > MAX_MIGRATION_CHAIN_LENGTH(6)"
	)


func test_persistence_layer_migrate_0_to_11_emits_zero_step_signals() -> void:
	# Arrange — connect a recorder for migration_step_completed.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.migration_step_completed.connect(_record_step)

	# Act
	PersistenceLayer.migrate(0, 11)

	# Assert — fail-fast pre-check runs BEFORE the loop, so no step ever
	# executed; therefore zero migration_step_completed emits.
	assert_eq(
		_step_signals.size(),
		0,
		"fail-fast pre-check must run BEFORE any step (zero migration_step_completed emits)"
	)


func test_persistence_layer_migrate_0_to_11_emits_critical_save_failed_once() -> void:
	# Arrange
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.critical_save_failed.connect(_record_critical)

	# Act
	PersistenceLayer.migrate(0, 11)

	# Assert — exactly one critical_save_failed with the spec'd code + key.
	assert_eq(
		_critical_signals.size(),
		1,
		"critical_save_failed must emit exactly once on MIGRATION_CHAIN_TOO_LONG"
	)
	assert_eq(
		_critical_signals[0]["error_code"],
		"MIGRATION_CHAIN_TOO_LONG",
		"error_code must be 'MIGRATION_CHAIN_TOO_LONG'"
	)
	assert_eq(
		_critical_signals[0]["key"],
		"",
		"key must be empty — pre-check has no per-key context"
	)


func test_persistence_layer_migrate_0_to_11_routes_through_corrupt_path() -> void:
	# Arrange — connect both Rule 9 signals to assert ordering:
	# corrupt_save_recovered must fire BEFORE critical_save_failed.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.get(CACHE_VAR_NAME)["pre_check_canary"] = "should_be_wiped"
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
	PersistenceLayer.migrate(0, 11)

	# Assert — Rule 9 ordering preserved on the pre-check failure path.
	assert_eq(event_order.size(), 2, "both Rule 9 signals must fire exactly once")
	assert_eq(
		event_order[0],
		"corrupt_save_recovered",
		"corrupt_save_recovered MUST fire before critical_save_failed (AC-15b ordering)"
	)
	assert_eq(event_order[1], "critical_save_failed")

	# AND the cache is wiped to schema-only baseline (Corrupt substate).
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	assert_false(
		cache.has("pre_check_canary"),
		"cache must be wiped to schema-only baseline (Corrupt substate)"
	)
	assert_eq(
		cache.get("schema_version", -1),
		PersistenceLayer.SCHEMA_VERSION,
		"cache must equal {schema_version: SCHEMA_VERSION} post-wipe"
	)


func test_persistence_layer_migrate_chain_too_long_does_not_raise_suppression() -> void:
	# Arrange — suppression flag should NEVER turn on for the pre-check
	# failure path (it short-circuits BEFORE the chain loop).
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(SUPPRESS_VAR_NAME, false)

	# Act
	PersistenceLayer.migrate(0, 11)

	# Assert — flag stayed false throughout; a subsequent write emits normally.
	assert_false(
		PersistenceLayer.get(SUPPRESS_VAR_NAME),
		"_suppress_write_completed must remain false on pre-check failure"
	)


# ----------------------------------------------------------------------------
# Boundary: chain length == MAX_MIGRATION_CHAIN_LENGTH (6) must PASS the
# pre-check. This proves the inequality is `>` not `>=` — a 6-step chain
# is the allowed maximum, not the rejected boundary.
# ----------------------------------------------------------------------------

func test_persistence_layer_migrate_chain_length_at_max_passes_pre_check() -> void:
	# Arrange — schema 0 → 6 is exactly MAX_MIGRATION_CHAIN_LENGTH.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.migration_step_completed.connect(_record_step)
	PersistenceLayer.critical_save_failed.connect(_record_critical)

	# Act
	var ok: bool = PersistenceLayer.migrate(0, PersistenceLayer.MAX_MIGRATION_CHAIN_LENGTH)

	# Assert — 6-step chain runs through (no pre-check failure).
	assert_true(
		ok,
		"chain length == MAX_MIGRATION_CHAIN_LENGTH(6) must PASS the pre-check"
	)
	assert_eq(
		_step_signals.size(),
		PersistenceLayer.MAX_MIGRATION_CHAIN_LENGTH,
		"a chain of exactly MAX_MIGRATION_CHAIN_LENGTH must emit one step signal per step"
	)
	assert_eq(
		_critical_signals.size(),
		0,
		"no critical_save_failed on the boundary-allowed chain"
	)
