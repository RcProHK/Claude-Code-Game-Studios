# StatSystem — Story 007 stat_clamped telemetry (AC-21, ADVISORY) Unit Tests.
#
# Scope:
#   AC-21 — GIVEN STR=998, WHEN apply_stat_delta(STR, PR_BREAKTHROUGH, 5.0) is
#           called (raw target 1003 → clamp 999), THEN stat_clamped(STR, 1003.0,
#           999.0) emits EXACTLY once. (ADVISORY — does not block Done; this is the
#           #28 Telemetry hook for balance tuning.)
#
# Also confirms the negative-telemetry case: a mutation that does NOT clamp emits
# no stat_clamped, so #28 only sees genuine boundary hits.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-21 (Rule 16 telemetry subset)
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
	# Drive STR to 998 via DEBUG_OVERRIDE. 10 + 988 = 998.
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 988.0)


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_clamp_telemetry_emits_once_with_exact_payload() -> void:
	# Arrange: STR == 998 (from before_each).
	assert_eq(_sut.get_stat(_sut.StatId.STR), 998.0, "precondition: STR is 998.0")
	watch_signals(_sut)

	# Act: 998 + 5 = 1003 → clamp 999.
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 5.0)

	# Assert: AC-21 — telemetry fires once carrying the raw attempt + clamped result.
	assert_signal_emit_count(_sut, "stat_clamped", 1,
		"AC-21: stat_clamped must emit exactly once on a clamp")
	var params: Array = get_signal_parameters(_sut, "stat_clamped")
	assert_eq(params[0], _sut.StatId.STR, "AC-21: stat_clamped stat_id must be STR")
	assert_eq(params[1], 1003.0, "AC-21: stat_clamped attempted_value must be the raw 1003.0")
	assert_eq(params[2], StatSystem.MAX_STAT_VALUE, "AC-21: stat_clamped clamped_value must be 999.0")


func test_no_clamp_emits_no_telemetry() -> void:
	# Negative case: a sub-ceiling mutation must NOT fire telemetry. 998 + 1 = 999
	# exactly — lands on the boundary without clamping (EC-10).
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-21 — no clamp means no telemetry noise for #28.
	assert_signal_emit_count(_sut, "stat_clamped", 0,
		"AC-21: a non-clamping mutation must NOT emit stat_clamped")
	assert_eq(_sut.get_stat(_sut.StatId.STR), StatSystem.MAX_STAT_VALUE,
		"sanity: 998 + 1 lands exactly on 999")
