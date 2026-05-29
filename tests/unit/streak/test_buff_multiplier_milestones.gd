## Unit tests for StreakSystem Story 004 — Buff Multiplier + Milestone Thresholds.
##
## Covers:
##   AC-ss-buff-1: streak_count 0 → baseline 1.0
##   AC-ss-buff-2: each milestone → its multiplier; 90 → 2.0 cap
##   AC-ss-buff-3: milestone invariants (ascending + non-decreasing) hold
##   AC-ss-buff-4: between milestones → most recent passed step (not interpolated)
##
## Story: production/epics/streak-system/story-004-buff-multiplier-milestones.md
## Test evidence path: tests/unit/streak/test_buff_multiplier_milestones.gd
extends GutTest


func _make_streak() -> StreakSystem:
	var s := StreakSystem.new()
	autofree(s)  # not in tree → _ready() does not run (pure-function tests)
	return s


# ---------------------------------------------------------------------------
# AC-ss-buff-1: baseline
# ---------------------------------------------------------------------------

func test_streak_count_zero_returns_baseline() -> void:
	var s := _make_streak()
	s._streak_count = 0
	assert_almost_eq(s.get_streak_buff_multiplier(), 1.0, 0.001,
		"streak_count 0 → baseline 1.0")


# ---------------------------------------------------------------------------
# AC-ss-buff-2: milestone table + cap
# ---------------------------------------------------------------------------

func test_milestone_values_match_table() -> void:
	var s := _make_streak()
	var table := {1: 1.1, 7: 1.25, 14: 1.4, 30: 1.6, 60: 1.8, 90: 2.0}
	for count: int in table:
		s._streak_count = count
		assert_almost_eq(s.get_streak_buff_multiplier(), table[count], 0.001,
			"streak_count %d → %f" % [count, table[count]])


func test_above_last_milestone_caps_at_max() -> void:
	var s := _make_streak()
	s._streak_count = 200
	assert_almost_eq(s.get_streak_buff_multiplier(), 2.0, 0.001,
		"streak_count above last milestone caps at MAX_BUFF_MULTIPLIER (2.0)")


# ---------------------------------------------------------------------------
# AC-ss-buff-3: invariants hold
# ---------------------------------------------------------------------------

func test_milestone_invariants_pass() -> void:
	var s := _make_streak()
	s._assert_milestone_invariants()  # must not trip in debug build
	# Direct verification of the invariant the assert guards:
	for i in range(StreakSystem.MILESTONE_THRESHOLDS.size() - 1):
		assert_lt(StreakSystem.MILESTONE_THRESHOLDS[i], StreakSystem.MILESTONE_THRESHOLDS[i + 1],
			"thresholds strictly ascending at index %d" % i)
	assert_eq(
		StreakSystem.MILESTONE_THRESHOLDS.size(),
		StreakSystem.MILESTONE_MULTIPLIERS.size(),
		"thresholds and multipliers arrays must be the same length"
	)


# ---------------------------------------------------------------------------
# AC-ss-buff-4: step function (not interpolated)
# ---------------------------------------------------------------------------

func test_between_milestones_returns_lower_step() -> void:
	var s := _make_streak()
	s._streak_count = 10  # between milestones 7 and 14
	assert_almost_eq(s.get_streak_buff_multiplier(), 1.25, 0.001,
		"streak_count 10 → 7-day step value 1.25 (step function, not interpolated)")
