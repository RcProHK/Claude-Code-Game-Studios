## Integration tests for StreakSystem Story 010 — Phone-Lost retro-credit (AC-37 / FR-1).
##
## Falsifiable Test #3 (GDD Section B): a real workout completed while the phone was
## offline is delivered LATE by GymSys (a past timestamp). The directional drift gate
## (Story 010 revision of Story 002) must ACCEPT such past events — the symmetric gate
## wrongly rejected them, violating Pillar 1 (real body, real power).
##
## Scoped to the SHIPPED surface: the implementation tracks `_streak_count` +
## `_last_workout_date_local` and derives `get_streak_buff_multiplier()`; it has NO
## `streak_changed` / `streak_milestone_reached` signal and NO milestone-unlocked Array
## (those GDD constructs were not implemented by Stories 001-008). Assertions therefore
## verify streak COUNT + buff MULTIPLIER + drift-gate acceptance, not signals.
##
## Live-backend cursor replay (GymSys actually re-emitting missed events by last_event_id)
## is ADR-0002 VS-tier scope — OUT OF SCOPE here. This validates Streak's acceptance side.
##
## Time is pinned via the _now_utc_override seam so the gate is fully deterministic.
##
## Story: production/epics/streak-system/story-010-phone-lost-retro-credit.md
extends GutTest
const StreakSystemScript := preload("res://src/autoload/streak_system.gd")


## Mock GameStateMachine — satisfies the connect_for_initial_state subscription seam.
class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


## Minimal mock PersistenceLayer — write() always succeeds (hermetic, no real autoload).
class StubPersistence extends RefCounted:
	signal critical_save_failed(error_code: String, key: String)
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


## Builds a booted StreakSystem (READY) with mocks + pinned now. tz offset 0 (UTC) so the
## local calendar date equals the UTC calendar date.
func _make_streak(now_utc: int) -> StreakSystemScript:
	var streak := StreakSystemScript.new()
	streak._gsm = MockGSM.new()
	streak._persistence = StubPersistence.new()
	streak._now_utc_override = now_utc
	streak._tz_offset_seconds = 0
	add_child_autofree(streak)  # _ready() → BOOTING→READY (load is a no-op stub)
	return streak


## Unix UTC seconds at noon of the given calendar day (DST-irrelevant anchor).
func _noon_utc(year: int, month: int, day: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day,
		"hour": 12, "minute": 0, "second": 0,
	}))


# ---------------------------------------------------------------------------
# AC-37: Phone-Lost retro-credit sequence (offline Day30, reconnect Day32)
# ---------------------------------------------------------------------------

func test_retro_then_current_event_credits_then_gap_resets() -> void:
	# Arrange — "now" is Day32; player had a 29-day streak ending Day29.
	var day29_utc := _noon_utc(2026, 4, 29)
	var day30_utc := _noon_utc(2026, 4, 30)
	var day32_utc := _noon_utc(2026, 5, 2)
	var day37_utc := _noon_utc(2026, 5, 7)
	var streak := _make_streak(day32_utc)
	streak._streak_count = 29
	streak._last_workout_date_local = 20260429
	streak._last_accepted_completed_at_utc = day29_utc
	watch_signals(streak)

	# Act 1 — the retro (offline Day30) event arrives late, 2 days in the past.
	streak._on_workout_completed(day30_utc)

	# Assert 1 — accepted (NOT rejected as drift); Day29→Day30 chain continues → streak 30.
	assert_signal_not_emitted(streak, "streak_persistence_failed",
		"AC-37: a real past (retro) workout must NOT be rejected as drift")
	assert_eq(streak._streak_count, 30, "AC-37: Day29→Day30 retro credit → streak 30")
	assert_almost_eq(streak.get_streak_buff_multiplier(), 1.6, 0.0001,
		"AC-37: buff multiplier reflects streak 30 (BUFF_STEP_MULTIPLIERS[3])")

	# Act 2 — the current (Day32) event; Day30→Day32 gap=2 ≤ STREAK_GRACE_GAP_DAYS.
	streak._on_workout_completed(day32_utc)

	# Assert 2 — EG-4 grace: a 2-day gap CONTINUES the chain (was gap_reset pre-EG-4).
	assert_eq(streak._streak_count, 31,
		"AC-37/EG-4: Day30→Day32 gap (2 ≤ grace 3) continues the chain → streak 31")
	assert_almost_eq(streak.get_streak_buff_multiplier(), 1.6, 0.0001,
		"AC-37/EG-4: buff multiplier stays at the 30-step (1.6) — chain unbroken")

	# Act 3 — Day37 event after 4 missed days; Day32→Day37 gap=5 > grace 3.
	streak._now_utc_override = day37_utc  # advance pinned clock past the gap
	streak._on_workout_completed(day37_utc)

	# Assert 3 — beyond-grace gap resets to 1 (forward-pull, current state matters).
	assert_eq(streak._streak_count, 1,
		"AC-37/EG-4: Day32→Day37 gap (5 > grace 3) resets streak to 1")
	assert_almost_eq(streak.get_streak_buff_multiplier(), 1.1, 0.0001,
		"AC-37: buff multiplier drops to the streak-1 step (1.1) — current state, not peak")


# ---------------------------------------------------------------------------
# AC-37a: directional gate — past accepted, forward tamper rejected
# ---------------------------------------------------------------------------

func test_past_timestamp_accepted_future_skew_rejected() -> void:
	var now := _noon_utc(2026, 5, 2)
	var streak := _make_streak(now)

	# A workout 5 days in the past (extreme Phone-Lost / Travel-Week) is ACCEPTED.
	assert_true(streak._passes_drift_gate(now - 5 * 86400),
		"AC-37a: a 5-day-old real workout passes the directional gate (was rejected by symmetric gate)")
	# A timestamp >300s in the FUTURE is still rejected (clock-forward tamper / backend error).
	assert_false(streak._passes_drift_gate(now + 400),
		"AC-37a: future skew > tolerance is rejected (anti clock-forward tamper)")


# ---------------------------------------------------------------------------
# AC-37b: same-day retro events do not double-credit
# ---------------------------------------------------------------------------

func test_same_day_retro_events_do_not_double_credit() -> void:
	var now := _noon_utc(2026, 5, 2)
	var streak := _make_streak(now)
	streak._streak_count = 5
	streak._last_workout_date_local = 20260430
	streak._last_accepted_completed_at_utc = _noon_utc(2026, 4, 30)

	var may1_noon := _noon_utc(2026, 5, 1)

	# First May-1 workout: Apr30→May1 consecutive → streak 6.
	streak._on_workout_completed(may1_noon)
	assert_eq(streak._streak_count, 6, "AC-37b: first May-1 workout increments streak to 6")

	# Second May-1 workout (monotonic-greater utc, SAME local day) → idempotent no-op.
	streak._on_workout_completed(may1_noon + 3600)
	assert_eq(streak._streak_count, 6,
		"AC-37b: a second workout on the same local calendar day must NOT double-credit (stays 6)")
