# StatSystem — Story 011 Formula F2 PR breakthrough at MAX_STAT_VALUE (AC-25) Unit Test.
#
# Scope: at STR = MAX_STAT_VALUE the diminishing factor is exactly 0
# (1 - (MAX/MAX)^PR_DIMINISH_EXP = 0), so the caller-computed pr_delta is 0.0. A delta
# of 0.0 is a VALID mutation (EC-10): apply_stat_delta returns true, STR is unchanged,
# no push_error fires, and stat_changed still emits once with old == new.
#
# A booted instance is required so the Suspended gate is open (READY).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-25 (Formula F2 + EC-10 + INV-2)
# Story: production/epics/stat-system/story-011-mutation-formulas.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut


func before_each() -> void:
	_sut = StatSystem.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._gsm = MockGSM.new()
	add_child_autofree(_sut)  # boot to READY
	# AC-25 precondition: STR at the ceiling.
	_sut._base[_sut.StatId.STR] = StatSystem.MAX_STAT_VALUE
	watch_signals(_sut)


func after_each() -> void:
	_sut = null


## INV-2: the diminishing factor at MAX_STAT_VALUE is exactly 0 (so the caller's delta is 0).
func test_diminishing_factor_at_max_is_zero() -> void:
	var diminishing: float = 1.0 - pow(
		StatSystem.MAX_STAT_VALUE / StatSystem.MAX_STAT_VALUE, StatSystem.PR_DIMINISH_EXP)
	assert_almost_eq(diminishing, 0.0, 0.00001,
		"INV-2: diminishing_factor(MAX_STAT_VALUE) must be exactly 0")


## AC-25 / EC-10: a 0.0 PR delta at the ceiling is a valid no-op mutation.
func test_formula2_zero_delta_at_max_is_valid_noop() -> void:
	# Act — caller computed delta = 0.0 (diminishing = 0 at MAX).
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 0.0)

	# Assert — valid, unchanged, and still broadcasts (old == new).
	assert_true(ok, "AC-25: a 0.0 delta at MAX is a valid mutation (EC-10)")
	assert_eq(_sut.get_stat(_sut.StatId.STR), StatSystem.MAX_STAT_VALUE,
		"AC-25: STR must be unchanged at MAX_STAT_VALUE")
	assert_signal_emit_count(_sut, "stat_changed", 1,
		"AC-25 / EC-10: a 0.0 delta still emits stat_changed exactly once")
	var params: Array = get_signal_parameters(_sut, "stat_changed", 0)
	assert_eq(params[1], params[2],
		"AC-25: old_value == new_value for a zero-delta mutation")
