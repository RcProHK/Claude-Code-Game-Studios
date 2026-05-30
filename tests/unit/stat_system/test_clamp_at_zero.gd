# StatSystem — Story 007 Clamp at the 0.0 floor (AC-15) Unit Tests.
#
# Scope:
#   AC-15 — GIVEN STR=5 (set via DEBUG_OVERRIDE in a debug build), WHEN
#           apply_stat_delta(STR, DEBUG_OVERRIDE, -10.0) is called (raw target -5),
#           THEN STR clamps to 0.0, stat_clamped(STR, -5.0, 0.0) emits once,
#           stat_changed(STR, 5.0, 0.0, DEBUG_OVERRIDE, false) emits once, and
#           apply_stat_delta returns true (clamp is NOT an error).
#   EC-10 — an exact-boundary delta (-5.0 from STR=5 → 0.0) does NOT clamp:
#           no stat_clamped, still returns true.
#
# DEBUG_OVERRIDE is used to set STR below the default and to apply the negative
# delta because anti-decay (AC-17) exempts DEBUG_OVERRIDE — this isolates the
# clamp path from the anti-decay path.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-15 (Rule 11 clamping)
# Story: production/epics/stat-system/story-007-anti-decay-clamping.md
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
	add_child_autofree(_sut)  # boot to READY (read() null → STR == 10.0)
	# Arrange a known low baseline: drive STR to 5 via DEBUG_OVERRIDE (debug build).
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -5.0)


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_clamp_at_zero_returns_true() -> void:
	# Arrange: STR == 5 (from before_each).
	assert_eq(_sut.get_stat(_sut.StatId.STR), 5.0, "precondition: STR is 5.0")

	# Act: raw target = 5 + (-10) = -5 → clamps to 0.
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -10.0)

	# Assert: AC-15 — clamp is NOT an error.
	assert_true(ok, "AC-15: a clamped mutation must still return true (clamp is not an error)")


func test_clamp_at_zero_stores_floor_value() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -10.0)

	# Assert: AC-15 — the stored value is the 0.0 floor, not the raw -5.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 0.0,
		"AC-15: a below-floor target (-5) must clamp to 0.0")


func test_clamp_at_zero_emits_stat_clamped() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -10.0)

	# Assert: AC-15 — stat_clamped carries the raw attempt and the clamped result.
	assert_signal_emit_count(_sut, "stat_clamped", 1,
		"AC-15: a triggered clamp must emit stat_clamped exactly once")
	var params: Array = get_signal_parameters(_sut, "stat_clamped")
	assert_eq(params[0], _sut.StatId.STR, "AC-15: stat_clamped stat_id must be STR")
	assert_eq(params[1], -5.0, "AC-15: stat_clamped attempted_value must be the raw -5.0")
	assert_eq(params[2], 0.0, "AC-15: stat_clamped clamped_value must be 0.0")


func test_clamp_at_zero_emits_stat_changed_with_clamped_value() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -10.0)

	# Assert: AC-15 — stat_changed broadcasts the CLAMPED new value (0.0), not -5.
	assert_signal_emit_count(_sut, "stat_changed", 1,
		"AC-15: a clamped mutation still broadcasts stat_changed exactly once")
	var params: Array = get_signal_parameters(_sut, "stat_changed")
	assert_eq(params[0], _sut.StatId.STR, "AC-15: stat_changed stat_id must be STR")
	assert_eq(params[1], 5.0, "AC-15: stat_changed old_value must be 5.0")
	assert_eq(params[2], 0.0, "AC-15: stat_changed new_value must be the clamped 0.0")
	assert_eq(params[3], _sut.StatSource.DEBUG_OVERRIDE, "AC-15: stat_changed source must be DEBUG_OVERRIDE")
	assert_false(params[4], "AC-15: stat_changed is_base_change must be false")


func test_exact_floor_boundary_does_not_clamp() -> void:
	# EC-10: STR=5, delta=-5 lands EXACTLY on 0.0 — no clamp should trigger.
	watch_signals(_sut)

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -5.0)

	# Assert: EC-10 — exact boundary is not a clamp.
	assert_true(ok, "EC-10: an exact-boundary mutation succeeds")
	assert_eq(_sut.get_stat(_sut.StatId.STR), 0.0, "EC-10: STR lands exactly on 0.0")
	assert_signal_emit_count(_sut, "stat_clamped", 0,
		"EC-10: a target landing exactly on the floor must NOT emit stat_clamped")
