# StatSystem — Story 004 Boot Reconciliation, corrupt + out-of-range fallback Unit Tests.
#
# Scope:
#   AC-12  — a corrupt persisted value (NaN / Inf) falls back to DEFAULT_BASE_VALUE,
#            emits stat_critical_save_failed for that stat, and boot STILL reaches
#            READY (degraded mode — one bad stat must not brick boot).
#   AC-12b — out-of-range values clamp: below floor → 0.0, above ceiling → MAX_STAT_VALUE.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-12 / AC-12b
# Story: production/epics/stat-system/story-004-boot-reconciliation.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_gsm = MockGSM.new()
	_sut = StatSystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm


func after_each() -> void:
	_sut.free()
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_boot_corrupt_nan_falls_back_to_default() -> void:
	# Arrange: str persisted as NaN (corrupt save).
	_mock_persistence.write("stat.str", NAN)

	# Act
	add_child_autofree(_sut)
	await _sut.ready

	# Assert: AC-12 — corrupt value replaced by the 10.0 default.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 10.0,
		"AC-12: a NaN persisted STR must fall back to DEFAULT_BASE_VALUE (10.0)")


func test_boot_corrupt_nan_emits_critical_save_failed() -> void:
	# Arrange
	_mock_persistence.write("stat.str", NAN)
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await _sut.ready

	# Assert: AC-12 — the corrupt stat raises stat_critical_save_failed(STR).
	assert_signal_emit_count(_sut, "stat_critical_save_failed", 1,
		"AC-12: a corrupt stat must emit stat_critical_save_failed exactly once")
	var params: Array = get_signal_parameters(_sut, "stat_critical_save_failed")
	assert_eq(params[0], _sut.StatId.STR,
		"AC-12: stat_critical_save_failed must carry the offending stat_id (STR)")


func test_boot_corrupt_nan_still_reaches_ready() -> void:
	# Arrange
	_mock_persistence.write("stat.str", NAN)

	# Act
	add_child_autofree(_sut)
	await _sut.ready

	# Assert: AC-12 — degraded mode: one corrupt stat must NOT prevent boot.
	assert_eq(_sut._substate, StatSystem.Substate.READY,
		"AC-12: boot must reach READY in degraded mode despite a corrupt stat")


func test_boot_corrupt_inf_falls_back_to_default() -> void:
	# Arrange: vit persisted as +Inf — also a corrupt/unrecoverable value.
	_mock_persistence.write("stat.vit", INF)
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await _sut.ready

	# Assert: AC-12 — Inf is treated identically to NaN.
	assert_eq(_sut.get_stat(_sut.StatId.VIT), 10.0,
		"AC-12: an Inf persisted VIT must fall back to DEFAULT_BASE_VALUE (10.0)")
	assert_signal_emit_count(_sut, "stat_critical_save_failed", 1,
		"AC-12: an Inf stat must raise stat_critical_save_failed")


func test_boot_below_floor_clamps_to_zero() -> void:
	# Arrange: dex = -5.0 (below the 0.0 floor) — AC-12b.
	_mock_persistence.write("stat.dex", -5.0)

	# Act
	add_child_autofree(_sut)
	await _sut.ready

	# Assert: AC-12b — clamp up to the floor.
	assert_eq(_sut.get_stat(_sut.StatId.DEX), 0.0,
		"AC-12b: a below-floor DEX (-5) must clamp to 0.0")


func test_boot_above_ceiling_clamps_to_max() -> void:
	# Arrange: vit = 1500.0 (above the 999.0 ceiling) — AC-12b.
	_mock_persistence.write("stat.vit", 1500.0)

	# Act
	add_child_autofree(_sut)
	await _sut.ready

	# Assert: AC-12b — clamp down to MAX_STAT_VALUE.
	assert_eq(_sut.get_stat(_sut.StatId.VIT), StatSystem.MAX_STAT_VALUE,
		"AC-12b: an above-ceiling VIT (1500) must clamp to MAX_STAT_VALUE (999)")


func test_boot_clamp_is_not_a_critical_failure() -> void:
	# Arrange: an out-of-range (but finite) value is a recoverable clamp, NOT a
	# critical save failure (contrast with NaN/Inf).
	_mock_persistence.write("stat.dex", -5.0)
	_mock_persistence.write("stat.vit", 1500.0)
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await _sut.ready

	# Assert: AC-12b — clamping does not raise stat_critical_save_failed.
	assert_signal_emit_count(_sut, "stat_critical_save_failed", 0,
		"AC-12b: a finite out-of-range value clamps silently — no critical failure")
