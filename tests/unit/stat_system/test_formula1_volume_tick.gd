# StatSystem — Story 011 Formula F1 volume tick (AC-23) Unit Tests.
#
# Scope: F1 (per-tick volume increment) is COMPUTED BY THE CALLER (#18 VolumeTick) — the
# caller passes a pre-computed delta to apply_stat_delta. This test references the
# VOLUME_TICK_BASE constant (NOT a hardcoded 0.05) and proves that applying it as a
# VOLUME_TICK delta to STR raises STR by exactly that step, leaves DEX/VIT untouched, and
# fires stat_changed exactly once.
#
# A booted (add_child) instance is required so the Suspended gate is open (READY) — a
# fresh un-parented instance never leaves INITIALISING and would reject the mutation.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-23 (Formula F1)
# Story: production/epics/stat-system/story-011-mutation-formulas.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut


func before_each() -> void:
	_sut = StatSystem.new()
	_sut._persistence = MockPersistenceLayer.new()  # write() returns true
	_sut._gsm = MockGSM.new()
	add_child_autofree(_sut)  # boot to READY (STR=DEX=VIT=10.0)
	watch_signals(_sut)


func after_each() -> void:
	_sut = null


## AC-23: applying VOLUME_TICK_BASE as a VOLUME_TICK delta raises STR 10 → 10.05.
## Positive deltas are NOT blocked by anti-decay (Rule 12 only blocks negative).
func test_formula1_volume_tick_raises_str_by_base_step() -> void:
	# Arrange — reference the knob, do not hardcode the step.
	var step: float = StatSystem.VOLUME_TICK_BASE

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, step)

	# Assert — STR advanced by exactly the step.
	assert_true(ok, "AC-23: a positive VOLUME_TICK delta must succeed")
	assert_almost_eq(_sut.get_stat(_sut.StatId.STR), 10.0 + step, 0.0001,
		"AC-23: STR must advance from 10.0 by VOLUME_TICK_BASE (→ 10.05)")


## AC-23: a VOLUME_TICK on STR must NOT touch DEX or VIT.
func test_formula1_volume_tick_leaves_other_base_stats_unchanged() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, StatSystem.VOLUME_TICK_BASE)

	# Assert — DEX and VIT remain at their 10.0 boot defaults.
	assert_eq(_sut.get_stat(_sut.StatId.DEX), 10.0, "AC-23: DEX must be unchanged by a STR tick")
	assert_eq(_sut.get_stat(_sut.StatId.VIT), 10.0, "AC-23: VIT must be unchanged by a STR tick")


## AC-23: exactly one stat_changed emission for a single volume tick.
func test_formula1_volume_tick_emits_stat_changed_once() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, StatSystem.VOLUME_TICK_BASE)

	# Assert
	assert_signal_emit_count(_sut, "stat_changed", 1,
		"AC-23: a single volume tick must emit stat_changed exactly once")
	var params: Array = get_signal_parameters(_sut, "stat_changed", 0)
	assert_eq(params[0], _sut.StatId.STR, "AC-23: the emission must be for STR")
	assert_eq(params[3], _sut.StatSource.VOLUME_TICK, "AC-23: source must be VOLUME_TICK")
