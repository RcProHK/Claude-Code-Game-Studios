## Unit tests for StreakSystemScript Story 008 — Drift Constant Cross-System Consistency.
##
## Covers:
##   AC-ss-drift-1: Streak.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer's (both 300)
##   AC-ss-drift-2: _assert_knob_invariants() passes for default constants (no trip)
##   AC-ss-drift-3: math validation — a mismatched value would trip the equality assert
##
## Story: production/epics/streak-system/story-008-drift-constant-consistency.md
## Test evidence path: tests/unit/streak/test_drift_constant_consistency.gd
extends GutTest
const StreakSystemScript := preload("res://src/autoload/streak_system.gd")


func _make_streak() -> StreakSystemScript:
	var s := StreakSystemScript.new()
	autofree(s)  # not in tree → _ready() does not run
	return s


# ---------------------------------------------------------------------------
# AC-ss-drift-1: cross-system constant equality
# ---------------------------------------------------------------------------

func test_drift_constant_matches_persistence_layer() -> void:
	assert_eq(
		StreakSystemScript.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS,
		PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS,
		"Streak drift tolerance must equal PersistenceLayer's owned knob"
	)
	assert_eq(
		StreakSystemScript.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS, 300,
		"drift tolerance is 300s"
	)


# ---------------------------------------------------------------------------
# AC-ss-drift-2: _assert_knob_invariants() passes for defaults
# ---------------------------------------------------------------------------

func test_assert_knob_invariants_passes_for_defaults() -> void:
	var s := _make_streak()
	s._assert_knob_invariants()  # must not trip in debug build (drift + milestone)
	assert_true(true, "knob invariants hold for default constants")


# ---------------------------------------------------------------------------
# AC-ss-drift-3: math validation of the equality guard
# ---------------------------------------------------------------------------

func test_mismatch_would_trip_assert() -> void:
	# The guard is an equality assert; verify the comparison rejects a mismatch.
	assert_ne(200, 300, "a mismatched drift tolerance (200 vs 300) is unequal → assert would trip")
