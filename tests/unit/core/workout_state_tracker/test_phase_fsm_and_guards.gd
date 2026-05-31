# WorkoutStateTracker — Story 001 Phase FSM + Guards Tests
#
# Coverage:
#   AC-02 — Full phase sequence + rest_ended flag-only behavior
#   AC-08 — set_history append-only invariant
#   AC-31 — EC-01: workout_completed in IDLE dropped (truth gate)
#   AC-38 — EC-32: set_logged in WORKOUT_COMPLETE dropped (late event)
#   EC-06 — workout_started mid-workout force-flush
extends GutTest


func before_each() -> void:
	# Drain the deferred queue before resetting — EC-06 force-flush enqueues a
	# process_frame callback on the autoload singleton; without this yield the callback
	# could fire after the reset and corrupt the next test's starting phase.
	await get_tree().process_frame
	WorkoutStateTracker.set(&"_workout_phase", WorkoutStateTracker.WorkoutPhase.IDLE)
	# In-place clear preserves the typed Array[Dictionary] reference, avoiding
	# typed-Array reassignment pitfalls when assigning an untyped [] literal via set().
	WorkoutStateTracker.get(&"_set_history").clear()
	WorkoutStateTracker.set(&"_rest_ended_awaiting_next_set", false)


# ---------------------------------------------------------------------------
# AC-02: Full valid sequence with 5 phase_changed emissions
# ---------------------------------------------------------------------------

## Full workout sequence transitions correctly; rest_ended does NOT emit phase_changed.
func test_ac02_full_sequence_transitions_correctly() -> void:
	watch_signals(WorkoutStateTracker)

	# workout_started: IDLE → WARM_UP
	WorkoutStateTracker.call("_on_workout_started")
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.WARM_UP,
			"workout_started: IDLE → WARM_UP")
	assert_signal_emitted_with_parameters(WorkoutStateTracker, "phase_changed",
			[WorkoutStateTracker.WorkoutPhase.IDLE, WorkoutStateTracker.WorkoutPhase.WARM_UP])

	# set_logged: WARM_UP → SET_ACTIVE
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
			"set_logged: WARM_UP → SET_ACTIVE")

	# rest_started: SET_ACTIVE → REST_PERIOD
	WorkoutStateTracker.call("_on_rest_started")
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.REST_PERIOD,
			"rest_started: SET_ACTIVE → REST_PERIOD")

	# rest_ended: REST_PERIOD stays REST_PERIOD — flag only, no phase_changed
	WorkoutStateTracker.call("_on_rest_ended")
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.REST_PERIOD,
			"rest_ended: phase must stay REST_PERIOD (internal flag only)")
	assert_true(WorkoutStateTracker.get(&"_rest_ended_awaiting_next_set"),
			"rest_ended: _rest_ended_awaiting_next_set must be set to true")

	# set_logged: REST_PERIOD → SET_ACTIVE; clears flag
	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 80.0)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
			"set_logged: REST_PERIOD → SET_ACTIVE")
	assert_false(WorkoutStateTracker.get(&"_rest_ended_awaiting_next_set"),
			"set_logged must clear _rest_ended_awaiting_next_set flag")

	# workout_completed: SET_ACTIVE → WORKOUT_COMPLETE
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE,
			"workout_completed: SET_ACTIVE → WORKOUT_COMPLETE")

	# Exactly 5 real phase transitions emitted (IDLE→WU, WU→SA, SA→RP, RP→SA, SA→WC)
	# rest_ended is the 6th call but emits 0 phase_changed — verified above by spy count
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 5,
			"Exactly 5 phase_changed emissions for the full sequence (rest_ended excluded)")


## Consecutive set_logged in SET_ACTIVE must NOT emit phase_changed again.
func test_ac02_consecutive_set_logged_no_duplicate_phase_change() -> void:
	WorkoutStateTracker.call("_on_workout_started")   # IDLE → WARM_UP
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)  # WARM_UP → SET_ACTIVE
	watch_signals(WorkoutStateTracker)

	# Already in SET_ACTIVE — second set_logged must NOT emit phase_changed
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 0,
			"set_logged in SET_ACTIVE must not emit phase_changed (already in SET_ACTIVE)")


# ---------------------------------------------------------------------------
# AC-08: set_history append-only invariant
# ---------------------------------------------------------------------------

## set_history has N+1 entries after N+1 set_logged calls; prior entries unchanged.
func test_ac08_set_history_append_only() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"row", 10, 40.0)

	var history: Array = WorkoutStateTracker.get(&"_set_history")
	assert_eq(history.size(), 2, "2 set_logged calls → set_history.size() == 2")

	# Deep-copy snapshot before third append
	var entry_0_snapshot: Dictionary = history[0].duplicate(true)
	var entry_1_snapshot: Dictionary = history[1].duplicate(true)

	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 80.0)

	assert_eq(history.size(), 3, "3rd set_logged call → set_history.size() == 3")
	assert_eq(history[0], entry_0_snapshot,
			"Entry 0 must be unchanged after later appends (CF-4)")
	assert_eq(history[1], entry_1_snapshot,
			"Entry 1 must be unchanged after later appends (CF-4)")
	assert_eq(history[2].get("exercise_id"), &"squat",
			"Entry 2 must contain the third exercise_id")
	assert_eq(history[2].get("reps"), 5)
	assert_eq(history[2].get("weight"), 80.0)


## set_history is empty immediately after workout_started (no sets logged yet).
func test_ac08_set_history_empty_at_workout_start() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	assert_eq(WorkoutStateTracker.get(&"_set_history").size(), 0,
			"set_history must be empty at WARM_UP (no set_logged yet)")


# ---------------------------------------------------------------------------
# AC-31: EC-01 — workout_completed in IDLE is dropped (truth gate)
# ---------------------------------------------------------------------------

## workout_completed in IDLE is dropped; phase stays IDLE; no signals emitted.
func test_ac31_workout_completed_in_idle_is_dropped() -> void:
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.IDLE,
			"Precondition: must start in IDLE")
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.IDLE,
			"Phase must stay IDLE after EC-01 drop")
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 0,
			"phase_changed must NOT emit when workout_completed dropped in IDLE (EC-01)")
	assert_signal_emit_count(WorkoutStateTracker, "workout_completed_forwarded", 0,
			"workout_completed_forwarded must NOT emit when dropped in IDLE (AC-31)")


# ---------------------------------------------------------------------------
# AC-38: EC-32 — set_logged in WORKOUT_COMPLETE is dropped (late event)
# ---------------------------------------------------------------------------

## Late set_logged after workout sealed is dropped; set_history not appended.
func test_ac38_late_set_logged_in_workout_complete_dropped() -> void:
	# Advance to WORKOUT_COMPLETE
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE,
			"Precondition: must be in WORKOUT_COMPLETE")

	var size_before: int = WorkoutStateTracker.get(&"_set_history").size()
	watch_signals(WorkoutStateTracker)

	# Late backfill after seal — must be dropped (EC-32, Rule 16 NEVER #5)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 60.0)

	assert_eq(WorkoutStateTracker.get(&"_set_history").size(), size_before,
			"set_history must NOT append after WORKOUT_COMPLETE (EC-32)")
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 0,
			"phase_changed must NOT emit for dropped late set_logged")


# ---------------------------------------------------------------------------
# EC-06: workout_started mid-workout force-flushes prior workout
# ---------------------------------------------------------------------------

## workout_started in SET_ACTIVE force-flushes: synchronous WORKOUT_COMPLETE +
## deferred IDLE→WARM_UP chain completes within one process_frame tick.
func test_ec06_workout_started_in_set_active_force_flushes() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
			"Precondition: must be in SET_ACTIVE")
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_workout_started")

	# Synchronous effect: SET_ACTIVE → WORKOUT_COMPLETE
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE,
			"workout_started in SET_ACTIVE must synchronously transition to WORKOUT_COMPLETE")
	assert_signal_emitted_with_parameters(WorkoutStateTracker, "phase_changed",
			[WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
			WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE])

	# Deferred effect: IDLE→WARM_UP both complete within one process_frame tick
	# (ADR-0006 Contract 5 process_frame.connect CONNECT_ONE_SHOT — both in one lambda).
	await get_tree().process_frame

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
			WorkoutStateTracker.WorkoutPhase.WARM_UP,
			"After one process_frame: force-flush chain must end in WARM_UP (EC-06)")
	# Total phase_changed from this test: SET_ACTIVE→WC(1) + WC→IDLE(2) + IDLE→WU(3)
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 3,
			"EC-06 force-flush chain emits exactly 3 phase_changed signals")
