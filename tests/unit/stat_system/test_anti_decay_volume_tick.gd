# StatSystem — Story 007 Anti-decay rejection (AC-17) Unit Tests.
#
# Scope:
#   AC-17 — GIVEN STR=20, WHEN apply_stat_delta(STR, VOLUME_TICK, -1.0) is called
#           (negative delta on a base stat from VOLUME_TICK), THEN returns false,
#           stat_mutation_rejected(STR, VOLUME_TICK, -1.0, "base_stat_decay_blocked")
#           emits, NO stat_changed emits, and STR remains 20.0 (Rule 12 Pillar 1
#           anti-fabrication — base stats cannot decay via workout sources).
#
#   Exemption coverage (Rule 12):
#     - PR_BREAKTHROUGH negative → also blocked (same rule, second workout source).
#     - DEBUG_OVERRIDE negative  → NOT blocked (debug/test exemption).
#     - EQUIPMENT path           → never reaches apply_stat_delta (modifier path);
#                                  derived-stat drops via modifier removal are allowed.
#
# STR is driven to 20 via DEBUG_OVERRIDE (the exempt source) to set the precondition
# without tripping the very rule under test.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-17 (Rule 12 anti-decay)
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
	# Drive STR to 20 via the exempt DEBUG_OVERRIDE source. 10 + 10 = 20.
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 10.0)


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_volume_tick_negative_returns_false() -> void:
	# Arrange: STR == 20 (from before_each).
	assert_eq(_sut.get_stat(_sut.StatId.STR), 20.0, "precondition: STR is 20.0")

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, -1.0)

	# Assert: AC-17 — anti-decay IS an error (unlike clamping).
	assert_false(ok, "AC-17: a negative VOLUME_TICK on a base stat must return false")


func test_volume_tick_negative_leaves_stat_unchanged() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, -1.0)

	# Assert: AC-17 — the blocked mutation must not move STR.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 20.0,
		"AC-17: a blocked decay must leave STR at 20.0 (unchanged)")


func test_volume_tick_negative_emits_rejection() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, -1.0)

	# Assert: AC-17 — the reject is surfaced with the canonical reason string.
	assert_signal_emit_count(_sut, "stat_mutation_rejected", 1,
		"AC-17: a blocked decay must emit stat_mutation_rejected once")
	var params: Array = get_signal_parameters(_sut, "stat_mutation_rejected")
	assert_eq(params[0], _sut.StatId.STR, "AC-17: rejected stat_id must be STR")
	assert_eq(params[1], _sut.StatSource.VOLUME_TICK, "AC-17: rejected source must be VOLUME_TICK")
	assert_eq(params[2], -1.0, "AC-17: rejected delta must be -1.0")
	assert_eq(params[3], "base_stat_decay_blocked", "AC-17: reason must be 'base_stat_decay_blocked'")


func test_volume_tick_negative_emits_no_stat_changed() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, -1.0)

	# Assert: AC-17 — a blocked mutation never broadcasts a change.
	assert_signal_emit_count(_sut, "stat_changed", 0,
		"AC-17: a blocked decay must NOT emit stat_changed")


func test_pr_breakthrough_negative_also_blocked() -> void:
	# Rule 12 — the other workout source is blocked identically.
	watch_signals(_sut)

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, -1.0)

	# Assert
	assert_false(ok, "Rule 12: a negative PR_BREAKTHROUGH on a base stat is also blocked")
	assert_eq(_sut.get_stat(_sut.StatId.STR), 20.0, "Rule 12: STR unchanged after blocked PR decay")
	var params: Array = get_signal_parameters(_sut, "stat_mutation_rejected")
	assert_eq(params[3], "base_stat_decay_blocked", "Rule 12: reason is 'base_stat_decay_blocked'")


func test_debug_override_negative_is_exempt() -> void:
	# Rule 12 exemption — DEBUG_OVERRIDE CAN push a base stat down (debug/test use).
	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, -5.0)

	# Assert: the exempt source succeeds and moves the stat.
	assert_true(ok, "Rule 12 exemption: a negative DEBUG_OVERRIDE must NOT be blocked")
	assert_eq(_sut.get_stat(_sut.StatId.STR), 15.0,
		"Rule 12 exemption: DEBUG_OVERRIDE -5 applies (20 → 15)")
