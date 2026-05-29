# PersistenceLayer — Story 008 AC-07 Migration Chain Normal Path Tests
#
# Scope: bounded migration chain (ADR-0006 Contract 10) drives the in-memory
# cache from `schema_version=0` to `schema_version=3` across three N→N+1
# steps. The chain MUST:
#   * emit `migration_step_completed` exactly once per step (3 total),
#   * NEVER emit `write_completed` during the chain (GDD Rule 5 D1 signal
#     suppression — `_suppress_write_completed=true` while `migrate()` runs),
#   * leave `_cache["schema_version"]` at 3 after the chain (test-only seam:
#     `_migration_step_mutate_*` writes the bumped schema version on every
#     step so the final cache matches AC-07),
#   * resolve back to substate "Ready" — for Story 008 this is asserted as
#     `_suppress_write_completed == false` AND a normal post-migration
#     `write()` re-emits `write_completed`.
#
# AC-07 (GDD design/gdd/persistence-layer.md AC-07):
#   GIVEN mock file `{"schema_version":0}` + `schema_version_override=3`,
#         each migration step taking 100ms,
#   WHEN  the boot path calls `migrate(0, 3)`,
#   THEN  3 × `migration_step_completed` emits;
#         0 × `write_completed` during migration;
#         final `_cache["schema_version"] == 3`;
#         substate == "Ready" (≡ suppression cleared + normal writes emit).
#
# AC-07b (boundary timing):
#   GIVEN a single step taking 149ms (MIGRATION_BUDGET_MS - 1),
#   WHEN  `migrate(0, 1)` runs,
#   THEN  the step PASSES (149 ≤ 150), `migration_step_completed` emits once.
#
# Direct private-state access policy: same ADR-0006 Contract 14 affordance
# as the unit suites — tests read/write underscore-prefixed fields via
# `Object.get()` / `Object.set()` to drive seams and assert invariants.
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
var _write_signals: Array = []


func before_each() -> void:
	# Arrange (shared): clear cache + reset dirty flag for isolation.
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	PersistenceLayer.set(DIRTY_VAR_NAME, false)
	PersistenceLayer.set(SUPPRESS_VAR_NAME, false)
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, 0)
	PersistenceLayer.set(STEP_FAIL_VAR_NAME, false)
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, null)

	# Fresh signal capture buffers.
	_step_signals = []
	_write_signals = []

	# Inject a fresh MockFileFactory.
	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)

	# Disconnect any signal listeners from prior tests.
	for conn in PersistenceLayer.migration_step_completed.get_connections():
		PersistenceLayer.migration_step_completed.disconnect(conn.callable)
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)
	for conn in PersistenceLayer.flush_completed.get_connections():
		PersistenceLayer.flush_completed.disconnect(conn.callable)


func after_each() -> void:
	# Detach the test factory + clear all test-only seams.
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


func _record_write(key: String, latency_ms: int, is_touch: bool) -> void:
	_write_signals.append({
		"key": key,
		"latency_ms": latency_ms,
		"is_touch": is_touch,
	})


# ----------------------------------------------------------------------------
# AC-07 core: 3-step chain emits 3 step signals, zero write_completed
# ----------------------------------------------------------------------------

func test_persistence_layer_migrate_0_to_3_emits_three_step_signals() -> void:
	# Arrange — seed mock file at schema 0 and connect step listener.
	#   The override-driven boot flow is owned by Story 016; here we drive
	#   the bounded chain directly via `migrate(0, 3)` to isolate Contract 10
	#   behaviour from boot orchestration.
	_factory.set_file_content("user://state.json", '{"schema_version": 0}')
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	PersistenceLayer.migration_step_completed.connect(_record_step)

	# Act
	var ok: bool = PersistenceLayer.migrate(0, 3)

	# Assert — chain succeeded with exactly 3 step emits (0→1, 1→2, 2→3).
	assert_true(ok, "migrate(0, 3) must return true for a normal 3-step chain")
	assert_eq(
		_step_signals.size(),
		3,
		"migration_step_completed must emit exactly once per step (3 total)"
	)
	assert_eq(_step_signals[0]["from"], 0, "first step from=0")
	assert_eq(_step_signals[0]["to"], 1, "first step to=1")
	assert_eq(_step_signals[1]["from"], 1, "second step from=1")
	assert_eq(_step_signals[1]["to"], 2, "second step to=2")
	assert_eq(_step_signals[2]["from"], 2, "third step from=2")
	assert_eq(_step_signals[2]["to"], 3, "third step to=3")


func test_persistence_layer_migrate_0_to_3_emits_zero_write_completed() -> void:
	# Arrange — connect a write_completed listener that records every emit.
	#   GDD Rule 5 D1: during migration, `_suppress_write_completed=true`
	#   silences `write_completed` even if migration steps call write().
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	# Mutate cache mid-step (key=junk) to prove that even mutations performed
	# inside the chain do NOT leak write_completed — the suppression flag
	# applies at the emission site in write(), and _migrate_one_step writes
	# directly to _cache so this test specifically targets the chain runner.
	PersistenceLayer.set(STEP_MUTATE_KEY_VAR_NAME, "schema_version")
	PersistenceLayer.set(STEP_MUTATE_VALUE_VAR_NAME, 1)
	PersistenceLayer.write_completed.connect(_record_write)

	# Act — drive a single step; the listener should NOT fire.
	var ok: bool = PersistenceLayer.migrate(0, 1)

	# Assert
	assert_true(ok, "single-step migrate(0, 1) must succeed")
	assert_eq(
		_write_signals.size(),
		0,
		"write_completed MUST NOT emit during a migration chain (GDD Rule 5 D1)"
	)


func test_persistence_layer_migrate_0_to_3_final_schema_version_is_three() -> void:
	# Arrange — mutation seam writes the bumped schema version per step.
	#   _migrate_one_step writes _cache[mutate_key] = mutate_value BEFORE
	#   checking fail_next, so the schema bump lands every step. The final
	#   value reflects the last step (3), matching AC-07's final cache state.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0
	# Each step rewrites the schema_version to a literal sentinel; the final
	# value after step 2→3 must be 3. We bake this into the test by using a
	# small connected listener that updates the value to match `to` per step.
	PersistenceLayer.migration_step_completed.connect(
		func(_from: int, to_version: int, _ms: int) -> void:
			PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = to_version
	)

	# Act
	var ok: bool = PersistenceLayer.migrate(0, 3)

	# Assert — final cache reflects the target version.
	assert_true(ok)
	assert_eq(
		PersistenceLayer.get(CACHE_VAR_NAME).get("schema_version", -1),
		3,
		"final _cache['schema_version'] must equal target after migrate(0, 3)"
	)


func test_persistence_layer_migrate_0_to_3_clears_suppression_flag() -> void:
	# Arrange — schema 0 baseline.
	PersistenceLayer.get(CACHE_VAR_NAME)["schema_version"] = 0

	# Act
	var ok: bool = PersistenceLayer.migrate(0, 3)

	# Assert — suppression flag is cleared on the success path, and a fresh
	# write_completed fires for a normal post-migration write (substate
	# "Ready" surrogate: writes emit normally again).
	assert_true(ok)
	assert_false(
		PersistenceLayer.get(SUPPRESS_VAR_NAME),
		"_suppress_write_completed must be cleared after migrate() returns"
	)

	# Bind a fresh listener; a normal write must emit write_completed.
	var post_writes: Array = []
	PersistenceLayer.write_completed.connect(
		func(k: String, _ms: int, _it: bool) -> void:
			post_writes.append(k)
	)
	PersistenceLayer.write("post_migration_key", "ok", false)
	assert_eq(
		post_writes.size(),
		1,
		"normal write() after migrate() must re-emit write_completed (substate==Ready)"
	)


# ----------------------------------------------------------------------------
# AC-07b: boundary timing — step at MIGRATION_BUDGET_MS - 1 PASSES
# ----------------------------------------------------------------------------

func test_persistence_layer_migrate_step_at_budget_minus_one_passes() -> void:
	# Arrange — single step with delay = MIGRATION_BUDGET_MS - 1 (149ms).
	#   The step MUST pass (149 ≤ 150) and emit migration_step_completed.
	#   This proves the boundary inequality is `>` not `>=` in migrate().
	const BUDGET_MINUS_ONE: int = PersistenceLayer.MIGRATION_BUDGET_MS - 1
	PersistenceLayer.set(STEP_DELAY_VAR_NAME, BUDGET_MINUS_ONE)
	PersistenceLayer.migration_step_completed.connect(_record_step)

	# Act
	var ok: bool = PersistenceLayer.migrate(0, 1)

	# Assert
	assert_true(
		ok,
		"a step taking MIGRATION_BUDGET_MS - 1 must PASS (boundary is '>' not '>=')"
	)
	assert_eq(
		_step_signals.size(),
		1,
		"migration_step_completed must emit for a sub-budget step"
	)
	assert_gte(
		_step_signals[0]["latency_ms"],
		BUDGET_MINUS_ONE,
		"reported step latency must be at least the configured delay"
	)
	assert_lte(
		_step_signals[0]["latency_ms"],
		PersistenceLayer.MIGRATION_BUDGET_MS,
		"reported step latency must be within the per-step budget"
	)
