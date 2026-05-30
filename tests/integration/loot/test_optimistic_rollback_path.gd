## test_optimistic_rollback_path.gd — Story 012 AC-33
##
## Governing story: production/epics/loot-drop-system/story-012-persistence-schema-migration.md
## Governing ADRs : ADR-0003 (Accepted 2026-05-30) 5-step optimistic persist; EC-17
##
## AC-33: when write_async() fails (returns false), LootDropSystem must:
##   1. Emit loot_disabled("persistence_unavailable")
##   2. Emit loot_rollback(drop_id) so #21 can cancel the reveal animation
##   3. Emit loot_optimistic_rollback telemetry
##   4. Clean up the idempotency cache (no leaked drop)
##
## Uses an inline MockPersistenceLootFail with configurable write_async() return value.
extends GutTest


# ── Inline mock with write_async support ──────────────────────────────────────

class MockPersistenceLootFail extends MockPersistenceLayer:
	## When false, write_async() simulates a Safari IDB timeout (EC-17).
	var write_ok: bool = true
	signal private_mode_detected

	func is_private_mode() -> bool:
		return false

	## Async-compatible write — returns synchronously (no actual await).
	func write_async(key: String, value: Variant) -> bool:
		if write_ok:
			return write(key, value)
		return false

	func list_keys(_prefix: String) -> Array:
		return []


# ── Fixture ────────────────────────────────────────────────────────────────────

var _sut: LootDropSystem
var _mock_persistence: MockPersistenceLootFail
var _config: LootRarityConfig
var _disabled_signals: Array = []
var _rollback_signals: Array = []
var _loot_dropped_signals: Array = []


func _make_config() -> LootRarityConfig:
	var c := LootRarityConfig.new()
	c.workout_weight = 0.75
	c.rng_weight = 0.25
	c.target_exercises = 5
	c.pr_bonus_per_pr = 0.12
	c.max_pr_factor = 1.25
	c.streak_scale = 28.0
	c.max_streak_bonus = 0.20
	c.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	c.tier_values = [0, 1, 2, 3, 4]
	return c


func before_each() -> void:
	_disabled_signals.clear()
	_rollback_signals.clear()
	_loot_dropped_signals.clear()

	_mock_persistence = MockPersistenceLootFail.new()
	_mock_persistence.write_ok = false  # Simulate write timeout by default.
	_config = _make_config()

	_sut = LootDropSystem.new()
	_sut._config = _config
	_sut._persistence = _mock_persistence
	_sut._gsm = null
	_sut._gymsys_client = null

	_sut.loot_disabled.connect(func(r): _disabled_signals.append(r))
	_sut.loot_rollback.connect(func(di): _rollback_signals.append(di))
	_sut.loot_dropped.connect(func(di, rt, it, tid): _loot_dropped_signals.append(di))

	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut.clear_telemetry()


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_config = null


# ── AC-33: optimistic rollback on write failure ────────────────────────────────

func test_ac33_loot_dropped_emitted_optimistically_before_rollback() -> void:
	# Step 2 (optimistic emit) fires before Step 3 (async write).
	await _sut._process_loot_trigger(
		"T-rollback", LootEnums.SourceEventKind.WORKOUT_DAILY,
		0.7, LootEnums.CeremonyDecision.FULL_CEREMONY
	)
	# loot_dropped was emitted even though write failed.
	assert_eq(_loot_dropped_signals.size(), 1,
		"AC-33: loot_dropped must be emitted optimistically (before await, before rollback)")


func test_ac33_loot_disabled_persistence_unavailable_emitted() -> void:
	await _sut._process_loot_trigger(
		"T-rollback2", LootEnums.SourceEventKind.WORKOUT_DAILY,
		0.7, LootEnums.CeremonyDecision.FULL_CEREMONY
	)
	assert_eq(_disabled_signals.size(), 1,
		"AC-33: loot_disabled must be emitted on write failure")
	assert_eq(_disabled_signals[0], "persistence_unavailable",
		"AC-33: loot_disabled reason must be 'persistence_unavailable'")


func test_ac33_loot_rollback_emitted_with_drop_id() -> void:
	await _sut._process_loot_trigger(
		"T-rollback3", LootEnums.SourceEventKind.WORKOUT_DAILY,
		0.7, LootEnums.CeremonyDecision.FULL_CEREMONY
	)
	assert_eq(_rollback_signals.size(), 1,
		"AC-33: loot_rollback must be emitted for #21 to cancel the reveal")


func test_ac33_loot_optimistic_rollback_telemetry_fired() -> void:
	await _sut._process_loot_trigger(
		"T-rollback4", LootEnums.SourceEventKind.WORKOUT_DAILY,
		0.7, LootEnums.CeremonyDecision.FULL_CEREMONY
	)
	var rollback_events := _sut.get_telemetry("loot_optimistic_rollback")
	assert_eq(rollback_events.size(), 1,
		"AC-33: loot_optimistic_rollback telemetry must fire exactly once")


func test_ac33_drops_by_transition_cleared_after_rollback() -> void:
	var tid: String = "T-rollback5"
	await _sut._process_loot_trigger(
		tid, LootEnums.SourceEventKind.WORKOUT_DAILY,
		0.7, LootEnums.CeremonyDecision.FULL_CEREMONY
	)
	# Idempotency cache must be cleaned up (no leaked drop reference).
	assert_false(_sut._drops_by_transition.has(tid),
		"AC-33: _drops_by_transition must NOT contain the rolled-back drop")


func test_ac33_no_pending_drop_after_rollback() -> void:
	await _sut._process_loot_trigger(
		"T-rollback6", LootEnums.SourceEventKind.WORKOUT_DAILY,
		0.7, LootEnums.CeremonyDecision.FULL_CEREMONY
	)
	assert_eq(_sut._pending_drops.size(), 0,
		"AC-33: no drop must remain in _pending_drops after rollback")


# ── Successful write path (control case) ──────────────────────────────────────

func test_successful_write_drops_added_to_pending() -> void:
	_mock_persistence.write_ok = true  # Simulate successful write.
	await _sut._process_loot_trigger(
		"T-success", LootEnums.SourceEventKind.WORKOUT_DAILY,
		0.6, LootEnums.CeremonyDecision.FULL_CEREMONY
	)
	assert_eq(_sut._pending_drops.size(), 1,
		"Successful write must add drop to _pending_drops")
	assert_eq(_disabled_signals.size(), 0,
		"Successful write must NOT emit loot_disabled")
	assert_eq(_rollback_signals.size(), 0,
		"Successful write must NOT emit loot_rollback")
