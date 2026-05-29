## Unit tests for StreakSystem Story 006 — Failed State + Error Handling (sticky single-emit).
##
## Covers:
##   AC-ss-fail-1: repeated failures emit streak_persistence_failed exactly once (sticky)
##   AC-ss-fail-2: non-streak namespace (e.g. stat.atk) is ignored — no state change
##   AC-ss-fail-3: streak.* failure → FAILED substate + emit
##
## Story: production/epics/streak-system/story-006-failed-state-error-handling.md
## Test evidence path: tests/unit/streak/test_failed_state_error_handling.gd
extends GutTest


## Minimal mock PersistenceLayer (only needs to satisfy the injection seam).
class MockPersistenceLayer extends RefCounted:
	signal critical_save_failed(error_code: String, key: String)
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


func _make_streak() -> StreakSystem:
	var s := StreakSystem.new()
	autofree(s)  # not in tree → _ready() does not run
	s._persistence = MockPersistenceLayer.new()
	return s


# ---------------------------------------------------------------------------
# AC-ss-fail-1: sticky single-emit
# ---------------------------------------------------------------------------

func test_failed_state_is_sticky_single_emit() -> void:
	var s := _make_streak()
	watch_signals(s)

	# Five subsequent streak.* failures
	for _i in range(5):
		s._on_persistence_failed("FLUSH_FAILED", "streak.last_workout_date_local")

	assert_eq(s._substate, StreakSystem.Substate.FAILED, "enters FAILED substate")
	assert_signal_emit_count(
		s, "streak_persistence_failed", 1,
		"streak_persistence_failed must emit exactly once total (sticky)"
	)


# ---------------------------------------------------------------------------
# AC-ss-fail-2: non-streak namespace ignored
# ---------------------------------------------------------------------------

func test_non_streak_namespace_is_ignored() -> void:
	var s := _make_streak()
	var substate_before := s._substate
	watch_signals(s)

	s._on_persistence_failed("QUOTA_EXHAUSTED", "stat.atk")

	assert_eq(s._substate, substate_before, "non-streak key must not change substate")
	assert_signal_not_emitted(
		s, "streak_persistence_failed",
		"non-streak key must emit nothing (namespace filter)"
	)


# ---------------------------------------------------------------------------
# AC-ss-fail-3: streak.* failure triggers FAILED + emit
# ---------------------------------------------------------------------------

func test_streak_namespace_failure_triggers_failed_and_emits() -> void:
	var s := _make_streak()
	watch_signals(s)

	s._on_persistence_failed("FLUSH_FAILED", "streak.last_workout_date_local")

	assert_eq(s._substate, StreakSystem.Substate.FAILED, "streak.* key → FAILED substate")
	assert_signal_emitted_with_parameters(
		s, "streak_persistence_failed",
		["FLUSH_FAILED", "streak.last_workout_date_local"], 0
	)


# ---------------------------------------------------------------------------
# Sticky FAILED: a workout arriving after FAILED must not re-emit
# ---------------------------------------------------------------------------

func test_workout_after_failed_does_not_reemit() -> void:
	var s := _make_streak()
	# Enter FAILED via an external critical failure (the sticky first emit).
	s._on_persistence_failed("FLUSH_FAILED", "streak.last_workout_date_local")
	watch_signals(s)  # start watching AFTER the initial sticky emit

	# A subsequent workout while FAILED must be ignored entirely (no drift-reject emit).
	s._now_utc_override = 1000
	s._on_workout_completed(99_999_999)  # far-future ts that would otherwise drift-reject

	assert_signal_not_emitted(
		s, "streak_persistence_failed",
		"workout while FAILED must not re-emit (sticky FAILED early-return in _on_workout_completed)"
	)
	assert_eq(s._substate, StreakSystem.Substate.FAILED, "substate remains FAILED")
