# StatSystem — Story 007 Clamp at the MAX_STAT_VALUE ceiling (AC-16) Unit Tests.
#
# Scope:
#   AC-16 — GIVEN STR=999 (MAX_STAT_VALUE), WHEN apply_stat_delta(STR,
#           PR_BREAKTHROUGH, 5.0) is called (raw target 1004), THEN STR clamps to
#           999, stat_clamped(STR, 1004.0, 999.0) emits once, stat_changed(STR,
#           999.0, 999.0, PR_BREAKTHROUGH, false) emits EXACTLY once (old == new
#           after clamp — EC-16 idempotent-subscriber case, no double-emit), and
#           apply_stat_delta returns true.
#   EC-10 — a delta that reaches EXACTLY MAX_STAT_VALUE does not clamp.
#
# STR is driven to 999 via DEBUG_OVERRIDE (debug build) so the ceiling test starts
# from the boundary. The clamping delta itself uses PR_BREAKTHROUGH per the AC.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-16 (Rule 11 clamping + EC-16)
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
	add_child_autofree(_sut)  # boot to READY (STR == 10.0)
	# Drive STR up to the 999 ceiling via DEBUG_OVERRIDE (debug build). 10 + 989 = 999.
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 989.0)


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_clamp_at_max_returns_true() -> void:
	# Arrange: STR == 999 (from before_each).
	assert_eq(_sut.get_stat(_sut.StatId.STR), StatSystem.MAX_STAT_VALUE, "precondition: STR is 999.0")

	# Act: raw target = 999 + 5 = 1004 → clamps to 999.
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 5.0)

	# Assert: AC-16 — clamp is not an error.
	assert_true(ok, "AC-16: a ceiling-clamped mutation must still return true")


func test_clamp_at_max_stores_ceiling_value() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 5.0)

	# Assert: AC-16 — the stored value stays at the 999 ceiling, not 1004.
	assert_eq(_sut.get_stat(_sut.StatId.STR), StatSystem.MAX_STAT_VALUE,
		"AC-16: an above-ceiling target (1004) must clamp to MAX_STAT_VALUE (999)")


func test_clamp_at_max_emits_stat_clamped() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 5.0)

	# Assert: AC-16 — stat_clamped carries the raw 1004 attempt and the 999 result.
	assert_signal_emit_count(_sut, "stat_clamped", 1,
		"AC-16: a ceiling clamp must emit stat_clamped exactly once")
	var params: Array = get_signal_parameters(_sut, "stat_clamped")
	assert_eq(params[0], _sut.StatId.STR, "AC-16: stat_clamped stat_id must be STR")
	assert_eq(params[1], 1004.0, "AC-16: stat_clamped attempted_value must be the raw 1004.0")
	assert_eq(params[2], StatSystem.MAX_STAT_VALUE, "AC-16: stat_clamped clamped_value must be 999.0")


func test_clamp_at_max_emits_stat_changed_once_with_equal_old_new() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 5.0)

	# Assert: AC-16 / EC-16 — stat_changed fires EXACTLY once even though old == new
	# (999 → 999 after clamp); subscribers must handle the idempotent payload.
	assert_signal_emit_count(_sut, "stat_changed", 1,
		"AC-16/EC-16: stat_changed must emit exactly once even when old == new (no double-emit)")
	var params: Array = get_signal_parameters(_sut, "stat_changed")
	assert_eq(params[1], StatSystem.MAX_STAT_VALUE, "AC-16: old_value is 999.0")
	assert_eq(params[2], StatSystem.MAX_STAT_VALUE, "AC-16: new_value is the clamped 999.0 (old == new)")
	assert_eq(params[3], _sut.StatSource.PR_BREAKTHROUGH, "AC-16: source is PR_BREAKTHROUGH")


func test_exact_ceiling_boundary_does_not_clamp() -> void:
	# EC-10: drive STR to 994, then +5 lands EXACTLY on 999 — no clamp.
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -5.0)  # 999 → 994
	assert_eq(_sut.get_stat(_sut.StatId.STR), 994.0, "precondition: STR is 994.0")
	watch_signals(_sut)

	# Act: 994 + 5 = 999 exactly.
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 5.0)

	# Assert: EC-10 — exact ceiling is not a clamp.
	assert_true(ok, "EC-10: an exact-ceiling mutation succeeds")
	assert_eq(_sut.get_stat(_sut.StatId.STR), StatSystem.MAX_STAT_VALUE, "EC-10: STR lands exactly on 999")
	assert_signal_emit_count(_sut, "stat_clamped", 0,
		"EC-10: a target landing exactly on the ceiling must NOT emit stat_clamped")
