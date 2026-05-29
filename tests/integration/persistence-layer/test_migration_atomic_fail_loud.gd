# PersistenceLayer — Story 008 AC-10 Migration Atomic-or-Fail-Loud Tests
#
# Scope: ADR-0006 Contract 10 atomic-revert invariant. A migration step that
# mutates `_cache` and then fails (e.g. its flush returns false, its
# transformation throws, etc.) MUST be reverted as if it had never run —
# `_cache` is restored to the pre-step snapshot, and `migrate()` returns
# false via the corrupt path. This is the "fail loud" half of the contract:
# partial mutations are forbidden.
#
# In production, mid-step failure surfaces as `_migrate_one_step()` returning
# false (after performing whatever partial mutation the step had reached).
# Here we drive that contract via three test-only seams:
#   * `_migration_step_mutate_key` / `_migration_step_mutate_value` —
#     simulate the partial mutation the step would have done,
#   * `_migration_step_fail_next` — force the step to return false AFTER
#     the mutation has been applied to `_cache`.
#
# AC-10 (GDD design/gdd/persistence-layer.md AC-10):
#   GIVEN a mock step that mutates `_cache` then "fails" (flush returns false),
#   WHEN  `migrate(0, 1)` runs,
#   THEN  the cache reverted to its pre-step state (mutation undone);
#         `migrate()` returned false;
#         critical_save_failed("MIGRATION_FAILED", "step_0_to_1") emitted.
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
# AC-10 core: mid-step mutation that fails MUST be reverted
# ----------------------------------------------------------------------------

func test_persistence_layer_migrate_failed_step_returns_false() -> void:
	# Arrange — pre-seed cache with a known baseline value. The failing
	# step will mutate `partial_payload` then return false; after migrate()
	# returns we expect the cache to look as if the step never ran.
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	cache["schema_version"] = 0
	cache["partial_payload"] = "original"

	# Configure the failure seam: write partial_payload="mutated_should_revert"
	# then return false. Without atomic revert the cache would carry the
	# mutated value AFTER migrate() returns; with atomic revert it reverts.
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "partial_payload")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, "mutated_should_revert")
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, true)

	# Act
	var ok: bool = PersistenceLayer.migrate(0, 1)

	# Assert
	assert_false(
		ok,
		"migrate() must return false when a step mutates then fails"
	)


func test_persistence_layer_migrate_failed_step_emits_migration_failed_critical() -> void:
	# Arrange — same failing-mutation seam as the previous test.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.get(CACHE_VAR_NAME)["partial_payload"] = "original"
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "partial_payload")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, "mutated_should_revert")
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, true)
	PersistenceLayer.critical_save_failed.connect(_record_critical)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — exactly one MIGRATION_FAILED (NOT MIGRATION_TIMEOUT, since
	# the step returned false within budget rather than running over time).
	assert_eq(
		_critical_signals.size(),
		1,
		"critical_save_failed must emit exactly once on step-returns-false"
	)
	assert_eq(
		_critical_signals[0]["error_code"],
		"MIGRATION_FAILED",
		"error_code must be 'MIGRATION_FAILED' when a step returns false within budget"
	)
	assert_eq(
		_critical_signals[0]["key"],
		"step_0_to_1",
		"key must carry the step label 'step_<from>_to_<to>' for diagnostics"
	)


func test_persistence_layer_migrate_failed_step_emits_no_step_completed_signal() -> void:
	# Arrange — failing seam + step recorder.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "partial_payload")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, "mutated_should_revert")
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, true)
	PersistenceLayer.migration_step_completed.connect(_record_step)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — failed step must NOT emit migration_step_completed.
	assert_eq(
		_step_signals.size(),
		0,
		"a failed step must NOT emit migration_step_completed"
	)


func test_persistence_layer_migrate_failed_step_then_corrupt_wipe_cache_baseline() -> void:
	# Arrange — failing seam.
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	cache["schema_version"] = 0
	cache["partial_payload"] = "original"
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "partial_payload")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, "mutated_should_revert")
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, true)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — after migrate() returns, the cache reflects the Rule 9 wipe
	# (corrupt path runs AFTER the pre-step revert). Net observable state:
	# schema-only baseline. The partial mutation is gone (proves revert),
	# AND the pre-step value is also gone (proves wipe is the final word).
	var post_cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	assert_false(
		post_cache.has("partial_payload"),
		"cache must NOT contain the partial mutation (atomic revert) NOR the original (Rule 9 wipe)"
	)
	assert_eq(
		post_cache.get("schema_version", -1),
		PersistenceLayer.SCHEMA_VERSION,
		"final cache must equal {schema_version: SCHEMA_VERSION} after corrupt wipe"
	)


# ----------------------------------------------------------------------------
# AC-10 strict revert proof: capture the cache state DURING the step (before
# corrupt-wipe runs) to prove the mutation was reverted BEFORE Rule 9 fires.
#
# Pattern: hook critical_save_failed; by the time that signal fires,
# `_trigger_corrupt` has already wiped the cache. But the contract is that
# `_cache = pre_snapshot` runs BEFORE `_trigger_corrupt` — we prove this
# indirectly by checking the wiped_byte_count surfaced via
# corrupt_save_recovered: it must equal the size of the pre-step snapshot
# JSON, NOT the size of the mutated snapshot.
# ----------------------------------------------------------------------------

func test_persistence_layer_migrate_revert_happens_before_corrupt_wipe() -> void:
	# Arrange — pre-step cache holds {schema_version:0, partial_payload:"original"}.
	# The step would mutate partial_payload to a LONGER string. If revert runs
	# BEFORE wipe, corrupt_save_recovered's wiped_byte_count == size of the
	# ORIGINAL JSON. If revert is skipped, it would equal the size of the
	# MUTATED JSON (which is larger).
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	cache["schema_version"] = 0
	cache["partial_payload"] = "original"

	# Compute the expected pre-step JSON byte count up-front.
	var pre_step_json: String = JSON.stringify(cache)
	var pre_step_bytes: int = pre_step_json.to_utf8_buffer().size()

	# Configure the failing mutation: write a much longer string.
	var long_mutated_value: String = "MUTATED_PAYLOAD_THAT_IS_DELIBERATELY_LONGER_THAN_THE_ORIGINAL_TO_DETECT_REVERT"
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "partial_payload")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, long_mutated_value)
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, true)

	var recovered_bytes: Array[int] = []
	PersistenceLayer.corrupt_save_recovered.connect(
		func(wiped_byte_count: int) -> void:
			recovered_bytes.append(wiped_byte_count)
	)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — corrupt_save_recovered's byte count matches the PRE-STEP
	# snapshot, proving revert ran BEFORE `_trigger_corrupt` measured the
	# cache size. If revert had been skipped, the count would equal the
	# (larger) mutated-snapshot byte count.
	assert_eq(
		recovered_bytes.size(),
		1,
		"corrupt_save_recovered must emit exactly once on AC-10 failure"
	)
	assert_eq(
		recovered_bytes[0],
		pre_step_bytes,
		"wiped_byte_count must equal the PRE-STEP snapshot size — proves revert ran BEFORE wipe"
	)


func test_persistence_layer_migrate_failed_step_clears_suppression_flag() -> void:
	# Arrange — failing seam.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "partial_payload")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, "x")
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, true)

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert — suppression cleared on the AC-10 failure path too. Subsequent
	# normal writes re-emit write_completed.
	assert_false(
		PersistenceLayer.get(SUPPRESS_VAR_NAME),
		"_suppress_write_completed must be cleared on the AC-10 failure path"
	)

	var post_writes: Array = []
	PersistenceLayer.write_completed.connect(
		func(k: String, _ms: int, _it: bool) -> void:
			post_writes.append(k)
	)
	PersistenceLayer.write("post_ac10_probe", 1, false)
	assert_eq(
		post_writes.size(),
		1,
		"normal write() after a failed migrate() must re-emit write_completed"
	)
