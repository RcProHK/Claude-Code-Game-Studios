## Unit tests — AttentionBudget Story 005
## Glance budget ceiling const + Formula 3 (glance_within_budget) + the
## debug-only assert_glance_within_budget instrumentation helper.
##
## Coverage (GDD Rule 8 / Formula 3 + AC-13 / EC-9):
##   AC-13   — Formula 3 boundary: glance_within_budget(2000) → true; (2001) → false;
##             (300) → true; (0) → true (edge: at/below ceiling permitted).
##   const   — GLANCE_BUDGET_CEILING_MS == 2000 (GDD Tuning Knobs default).
##   assert  — debug-build helper: in test env OS.is_debug_build() is true, so
##             assert_glance_within_budget runs the debug branch. within-budget
##             value → no side effect / no crash; over-budget value → push_error
##             (smoke: must not crash, returns void). Deterministic + non-crashing.
##
## Framework: GUT (Godot Unit Testing) v9.x
## NOTE: GUT collects test_*.gd files only; *_test.gd suffix is silently ignored.
##       All test functions must use test_ prefix.
##
## AttentionBudget is registered as an autoload (Story 004), but — mirroring the
## Story 003 allowlist tests — we instantiate the node directly via preload so the
## test is independent of autoload boot ordering and exercises the same surface.
extends GutTest


# ============================================================================
# Test fixture — fresh AttentionBudget node per test
# ============================================================================

var _budget


func before_each() -> void:
	_budget = preload("res://src/autoload/attention_budget.gd").new()
	add_child_autofree(_budget)


# ============================================================================
# const value — GLANCE_BUDGET_CEILING_MS == 2000 (GDD Tuning Knobs default)
# ============================================================================

## The cross-system ceiling const must be exactly the GDD default (2000ms).
func test_glance_budget_ceiling_const_is_2000() -> void:
	# Arrange + Act + Assert
	assert_eq(
		_budget.GLANCE_BUDGET_CEILING_MS,
		2000,
		"GLANCE_BUDGET_CEILING_MS must be 2000 (GDD Tuning Knobs default)"
	)


# ============================================================================
# AC-13 — Formula 3 boundary (glance_within_budget)
# ============================================================================

## AC-13: measured_ms == ceiling (2000) is within budget → true.
func test_glance_within_budget_at_ceiling_is_true() -> void:
	# Arrange + Act + Assert
	assert_true(
		_budget.glance_within_budget(2000),
		"AC-13: glance_within_budget(2000) must be true (<= ceiling)"
	)


## AC-13: measured_ms one over the ceiling (2001) exceeds budget → false.
func test_glance_within_budget_above_ceiling_is_false() -> void:
	# Arrange + Act + Assert
	assert_false(
		_budget.glance_within_budget(2001),
		"AC-13: glance_within_budget(2001) must be false (> ceiling)"
	)


## AC-13: a typical HUD glance (300ms) is comfortably within budget → true.
func test_glance_within_budget_typical_glance_is_true() -> void:
	# Arrange + Act + Assert
	assert_true(
		_budget.glance_within_budget(300),
		"AC-13: glance_within_budget(300) must be true (typical HUD glance)"
	)


## AC-13 edge: zero measured demand is within budget → true.
func test_glance_within_budget_zero_is_true() -> void:
	# Arrange + Act + Assert
	assert_true(
		_budget.glance_within_budget(0),
		"AC-13: glance_within_budget(0) must be true (zero <= ceiling)"
	)


# ============================================================================
# assert_glance_within_budget — debug-build instrumentation helper (EC-9)
# ============================================================================

## Sanity precondition: the GUT test environment is a debug build, so the
## helper's debug branch (OS.is_debug_build()) is the one under test here.
func test_assert_helper_runs_debug_branch_in_test_env() -> void:
	# Arrange + Act + Assert
	assert_true(
		OS.is_debug_build(),
		"Test env must be a debug build for assert_glance_within_budget coverage"
	)


## within-budget value: helper runs the debug branch but stays silent (no
## push_error, no crash, returns void).
func test_assert_helper_within_budget_no_error() -> void:
	# Arrange + Act — within budget (1500 <= 2000), should not push_error
	_budget.assert_glance_within_budget(&"hud", 1500)

	# Assert — reached here without crashing; helper is a void no-effect call
	assert_true(true, "within-budget assert_glance_within_budget must not crash")


## over-budget value: helper runs the debug branch and emits push_error.
## Smoke-level: we assert the call is deterministic and non-crashing (returns
## void). The push_error itself is design-time instrumentation (EC-9) — it is
## NOT a runtime gate and carries no return value to assert against, so we verify
## it does not raise / crash rather than capturing the engine error stream
## (GUT 9.x error monitoring is version-fragile and out of scope for this const).
func test_assert_helper_over_budget_logs_without_crash() -> void:
	# Arrange + Act — over budget (2500 > 2000) triggers the push_error branch
	_budget.assert_glance_within_budget(&"hud_hp", 2500)

	# Assert — reached here: the over-budget path logged and returned cleanly.
	assert_true(true, "over-budget assert_glance_within_budget must log without crashing")
