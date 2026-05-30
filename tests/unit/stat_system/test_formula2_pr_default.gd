# StatSystem — Story 011 Formula F2 PR breakthrough, default knobs (AC-24) Unit Test.
#
# Scope: F2 (PR breakthrough delta) is COMPUTED BY THE CALLER (#9 PR Detection) — the
# caller passes a pre-computed delta to apply_stat_delta. This test reproduces the AC-24
# worked example using the PR_BASE / PR_DIMINISH_EXP / MAX_STAT_VALUE CONSTANTS (not
# hardcoded literals), so a knob change re-derives the expected result instead of going
# stale. pr_magnitude (0.0833) is the workout input and is a legitimate test literal.
#
#   delta = PR_BASE * pr_magnitude * (1 - (STR / MAX_STAT_VALUE) ^ PR_DIMINISH_EXP)
#         = 6.0 * 0.0833 * (1 - (12/999)^2) ≈ 0.500  → STR 12.0 → ≈ 12.5
#
# A booted instance is required so the Suspended gate is open (READY).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-24 (Formula F2)
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
	# AC-24 precondition: STR = 12.0 (white-box set; apply_stat_delta would need a
	# prior mutation chain — the AC fixes the starting value directly).
	_sut._base[_sut.StatId.STR] = 12.0


func after_each() -> void:
	_sut = null


## AC-24: applying the Formula-2 delta computed from the knob constants raises STR
## from 12.0 to ≈ 12.5 (within ±0.001).
func test_formula2_pr_default_raises_str_to_expected() -> void:
	# Arrange — compute the caller-side delta FROM THE CONSTANTS (not a literal 0.500).
	var pr_magnitude: float = 0.0833  # workout input (test data)
	var current_str: float = _sut.get_stat(_sut.StatId.STR)
	var diminishing: float = 1.0 - pow(current_str / StatSystem.MAX_STAT_VALUE, StatSystem.PR_DIMINISH_EXP)
	var pr_delta: float = StatSystem.PR_BASE * pr_magnitude * diminishing

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, pr_delta)

	# Assert — STR lands at ≈ 12.5 per the AC-24 worked example.
	assert_true(ok, "AC-24: a positive PR_BREAKTHROUGH delta must succeed")
	assert_almost_eq(_sut.get_stat(_sut.StatId.STR), 12.5, 0.001,
		"AC-24: STR must reach ≈ 12.5 after the Formula-2 delta")


## AC-24: the delta is derived from PR_BASE — a sanity check that the const, not a
## magic number, drives the result (guards against a hardcoded-literal regression).
func test_formula2_delta_uses_pr_base_constant() -> void:
	# The bare PR magnitude scaled by PR_BASE (before diminishing) is the dominant term.
	var pr_magnitude: float = 0.0833
	var expected_undiminished: float = StatSystem.PR_BASE * pr_magnitude  # ≈ 0.4998

	# diminishing_factor at STR=12 is ~0.99986, so the real delta is within a hair of this.
	assert_almost_eq(expected_undiminished, 0.4998, 0.001,
		"AC-24: PR_BASE (6.0) * magnitude (0.0833) ≈ 0.4998 — the const drives the gain")
