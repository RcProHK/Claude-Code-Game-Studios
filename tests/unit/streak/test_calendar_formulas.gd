## Unit tests for StreakSystemScript Story 003 — Calendar Formulas (DST-robust day classification).
##
## Covers:
##   AC-ss-cal-1: local_calendar_date_from_utc returns a stable YYYYMMDD integer
##   AC-ss-cal-2: consecutive local days → true
##   AC-ss-cal-3: DST spring-forward boundary → noon-anchored arithmetic stays correct
##   AC-ss-cal-4: same local day → false
##   + month-boundary guard (raw integer subtraction would be wrong)
##   AC-40 (EG-4): chain_continuation_classification grace window — gap ∈ [1, 3] continues,
##   gap 0 / gap > STREAK_GRACE_GAP_DAYS does not (boundary-exact, EC-23)
##
## Pure-function tests: instance is never added to the tree, so _ready() never runs
## (no GSM / PersistenceLayer dependency).
##
## Story: production/epics/streak-system/story-003-calendar-formulas.md
## Test evidence path: tests/unit/streak/test_calendar_formulas.gd
extends GutTest
const StreakSystemScript := preload("res://src/autoload/streak_system.gd")


func _make_streak() -> StreakSystemScript:
	var s := StreakSystemScript.new()
	autofree(s)  # freed at teardown; not in tree → _ready() does not run
	return s


# ---------------------------------------------------------------------------
# AC-ss-cal-1: stable YYYYMMDD from UTC + tz offset
# ---------------------------------------------------------------------------

func test_local_calendar_date_from_utc_returns_stable_yyyymmdd() -> void:
	var s := _make_streak()
	# utc=1700000000, tz_offset=+8h(28800): local=1700028800
	#   day_start = floor(1700028800 / 86400) * 86400 = 19676 * 86400 = 1700006400
	#             = 2023-11-15 00:00:00 UTC
	#   noon      = 1700006400 + 43200 = 1700049600 = 2023-11-15 12:00:00 UTC
	#   → 20231115
	# (Previous expectation 20231113 was a miscalculated day_start in this comment.)
	assert_eq(
		s.local_calendar_date_from_utc(1700000000, 28800),
		20231115,
		"noon-anchored local date for utc=1700000000 tz=+8 must be 20231115"
	)


# ---------------------------------------------------------------------------
# AC-ss-cal-2: consecutive local days → true
# ---------------------------------------------------------------------------

func test_consecutive_days_returns_true() -> void:
	var s := _make_streak()
	assert_true(
		s.consecutive_day_classification(20240101, 20240102),
		"20240101 and 20240102 are consecutive"
	)
	# Symmetric (abs-based): reverse order must also be true
	assert_true(
		s.consecutive_day_classification(20240102, 20240101),
		"consecutive classification is order-independent"
	)


# ---------------------------------------------------------------------------
# AC-ss-cal-3: DST spring-forward boundary (US DST begins 2024-03-10)
# ---------------------------------------------------------------------------

func test_dst_boundary_consecutive_days() -> void:
	var s := _make_streak()
	assert_true(
		s.consecutive_day_classification(20240310, 20240311),
		"noon-anchored arithmetic identifies consecutive days across DST spring-forward"
	)


# ---------------------------------------------------------------------------
# AC-ss-cal-4: same local day → false
# ---------------------------------------------------------------------------

func test_same_day_is_not_consecutive() -> void:
	var s := _make_streak()
	assert_false(
		s.consecutive_day_classification(20240101, 20240101),
		"same calendar day is not consecutive"
	)


# ---------------------------------------------------------------------------
# Month-boundary guard: raw subtraction (20240201 - 20240131 = 70) would be wrong
# ---------------------------------------------------------------------------

func test_month_boundary_consecutive_days() -> void:
	var s := _make_streak()
	assert_true(
		s.consecutive_day_classification(20240131, 20240201),
		"Jan 31 → Feb 1 are consecutive (month boundary)"
	)
	assert_false(
		s.consecutive_day_classification(20240101, 20240103),
		"two calendar days apart is not consecutive"
	)


# ---------------------------------------------------------------------------
# AC-40 / EC-23 (EG-4): chain grace window — boundary-exact behavior
# ---------------------------------------------------------------------------

func test_chain_continuation_within_grace_window_returns_true() -> void:
	var s := _make_streak()
	# gap = 1, 2, 3 (== STREAK_GRACE_GAP_DAYS default 3) all continue the chain.
	assert_true(
		s.chain_continuation_classification(20260601, 20260602),
		"AC-40(a): gap=1 continues the chain"
	)
	assert_true(
		s.chain_continuation_classification(20260601, 20260603),
		"AC-40(b): gap=2 (one full rest day between) continues the chain"
	)
	assert_true(
		s.chain_continuation_classification(20260601, 20260604),
		"AC-40(c): gap=3 == STREAK_GRACE_GAP_DAYS boundary (inclusive) continues the chain"
	)


func test_chain_continuation_beyond_grace_or_same_day_returns_false() -> void:
	var s := _make_streak()
	assert_false(
		s.chain_continuation_classification(20260601, 20260605),
		"AC-40(d): gap=4 > STREAK_GRACE_GAP_DAYS breaks the chain"
	)
	assert_false(
		s.chain_continuation_classification(20260601, 20260601),
		"EC-23: same day (gap=0) is not a chain continuation (same-day branch owns it)"
	)


func test_chain_continuation_month_boundary_within_grace() -> void:
	var s := _make_streak()
	# Jan 31 → Feb 2: gap=2 across a month boundary (raw int subtraction would be 71).
	assert_true(
		s.chain_continuation_classification(20240131, 20240202),
		"AC-40: month-boundary gap=2 is correctly inside the grace window"
	)


func test_grace_knob_within_invariant_bounds() -> void:
	# EG-4 Tuning Knob invariant #5: STREAK_GRACE_GAP_DAYS ∈ [1, 4].
	assert_between(StreakSystemScript.STREAK_GRACE_GAP_DAYS, 1, 4,
		"STREAK_GRACE_GAP_DAYS must stay within the GDD safe range [1, 4]")


# ---------------------------------------------------------------------------
# Negative local-time guard: posmod floor-to-day (not truncate-toward-zero)
# ---------------------------------------------------------------------------

func test_negative_local_timestamp_floors_to_correct_day() -> void:
	var s := _make_streak()
	# utc=100, tz=-28800 → local=-28700 (pre-epoch local time).
	# Floor-to-day must yield 1969-12-31 noon, not 1970-01-01 (truncation bug).
	assert_eq(
		s.local_calendar_date_from_utc(100, -28800),
		19691231,
		"negative local timestamp must floor (not truncate) to the correct day"
	)
