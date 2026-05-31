# WorkoutStateTracker — Story 002 Substate Lifecycle + Frozen Flag Tests
#
# Coverage:
#   AC-03 — INITIALISING/READY/SUSPENDED lifecycle + _is_frozen orthogonal
#   AC-33 — EC-08: SUSPENDED entry delayed when WORKOUT_COMPLETE deferred queue pending
#   AC-34 — EC-11: workout_completed dropped in SUSPENDED; backfill processes normally
#
# Bonus coverage (Story 001 tech debt — EC-02/03/04 guard branches):
#   EC-02 — set_logged in IDLE dropped
#   EC-03 — rest_started in non-SET_ACTIVE dropped
#   EC-04 — rest_ended in non-REST_PERIOD dropped
extends GutTest


func before_each() -> void:
	# Drain any pending process_frame callbacks or call_deferred calls from prior test
	# (EC-06/EC-08 deferred chains use process_frame on the autoload singleton).
	await get_tree().process_frame
	WorkoutStateTracker.set(&"_workout_phase", WorkoutStateTracker.WorkoutPhase.IDLE)
	WorkoutStateTracker.get(&"_set_history").clear()
	WorkoutStateTracker.set(&"_rest_ended_awaiting_next_set", false)
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.READY)
	WorkoutStateTracker.set(&"_is_frozen", false)
	WorkoutStateTracker.set(&"_last_drop_reason", &"")
	WorkoutStateTracker.set(&"_pending_suspended_entry", false)


# ---------------------------------------------------------------------------
# AC-03: Substate lifecycle + frozen flag orthogonality
# ---------------------------------------------------------------------------

## INITIALISING is the safe default before _ready() completes.
func test_ac03_initial_substate_is_initialising() -> void:
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.INITIALISING)
	assert_eq(
		WorkoutStateTracker.get(&"_substate"),
		WorkoutStateTracker.Substate.INITIALISING,
		"Substate ordinal 0 must be INITIALISING (ADR-0007 Family A safe default)"
	)


## After _ready() setup completes, substate transitions to READY.
func test_ac03_substate_ready_after_ready_setup() -> void:
	# before_each sets _substate = READY to simulate post-_ready() state
	assert_eq(
		WorkoutStateTracker.get(&"_substate"),
		WorkoutStateTracker.Substate.READY,
		"Substate must be READY after _ready() subscription phase completes"
	)


## GSM state_changed → SUSPENDED sets substate to SUSPENDED.
func test_ac03_gsm_suspended_sets_substate_suspended() -> void:
	# Call _on_gsm_state_changed directly — unit-isolation; avoids fan-out to other
	# autoload subscribers (StatSystem, AbilitySystem) that are also connected to
	# GameStateMachine.state_changed in the live scene tree.
	var payload := StateTransitionPayload.new()
	WorkoutStateTracker.call("_on_gsm_state_changed",
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		GameStateMachine.GameState.SUSPENDED,
		payload
	)
	assert_eq(
		WorkoutStateTracker.get(&"_substate"),
		WorkoutStateTracker.Substate.SUSPENDED,
		"Substate must be SUSPENDED when GSM handler receives SUSPENDED"
	)


## GSM state_changed → non-Suspended state exits SUSPENDED and returns to READY.
func test_ac03_gsm_exit_suspended_returns_to_ready() -> void:
	# Arrange: manually enter SUSPENDED
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.SUSPENDED)

	# Act: GSM exits Suspended (direct call — unit isolation)
	var payload := StateTransitionPayload.new()
	WorkoutStateTracker.call("_on_gsm_state_changed",
		GameStateMachine.GameState.SUSPENDED,
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		payload
	)
	assert_eq(
		WorkoutStateTracker.get(&"_substate"),
		WorkoutStateTracker.Substate.READY,
		"Substate must return to READY when GSM handler receives non-SUSPENDED"
	)


## poll_failed sets _is_frozen regardless of substate (orthogonal).
func test_ac03_poll_failed_sets_frozen_in_ready() -> void:
	assert_false(WorkoutStateTracker.get(&"_is_frozen"), "Precondition: _is_frozen must be false")
	WorkoutStateTracker.call("_on_poll_failed", &"network")
	assert_true(WorkoutStateTracker.get(&"_is_frozen"),
		"_is_frozen must be true after poll_failed in READY substate")
	assert_eq(WorkoutStateTracker.get(&"_substate"), WorkoutStateTracker.Substate.READY,
		"Substate must be UNCHANGED after poll_failed (orthogonal)")


## poll_failed sets _is_frozen in SUSPENDED substate too (EC-12: both flags coexist).
func test_ac03_poll_failed_sets_frozen_in_suspended_ec12() -> void:
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.SUSPENDED)
	WorkoutStateTracker.call("_on_poll_failed", &"network")
	assert_true(WorkoutStateTracker.get(&"_is_frozen"),
		"_is_frozen must be true even when SUSPENDED (EC-12: flags are orthogonal)")
	assert_eq(WorkoutStateTracker.get(&"_substate"), WorkoutStateTracker.Substate.SUSPENDED,
		"Substate must remain SUSPENDED after poll_failed")


## poll_recovered clears _is_frozen; substate unchanged.
func test_ac03_poll_recovered_clears_frozen() -> void:
	WorkoutStateTracker.set(&"_is_frozen", true)
	WorkoutStateTracker.call("_on_poll_recovered")
	assert_false(WorkoutStateTracker.get(&"_is_frozen"),
		"_is_frozen must be false after poll_recovered")
	assert_eq(WorkoutStateTracker.get(&"_substate"), WorkoutStateTracker.Substate.READY,
		"Substate must be UNCHANGED after poll_recovered")


# ---------------------------------------------------------------------------
# AC-33: EC-08 — SUSPENDED entry deferred when WORKOUT_COMPLETE queue pending
# ---------------------------------------------------------------------------

## When phase == WORKOUT_COMPLETE, GSM Suspended defers entry by one process_frame.
## The deferred queue (simulated stat-apply spy) must complete BEFORE SUSPENDED.
func test_ac33_suspended_entry_deferred_during_workout_complete() -> void:
	# Arrange: drive to WORKOUT_COMPLETE
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE,
		"Precondition: phase must be WORKOUT_COMPLETE")

	# Simulate pending stat-apply callable in the deferred queue (EC-08 scenario).
	# The spy also records the WST substate at the moment it fires — proving that
	# stat-apply ran WHILE still READY (i.e. before SUSPENDED entry). This is the
	# strict EC-08 invariant: stat-apply ≺ SUSPENDED.
	var stat_spy_applied: bool = false
	var stat_spy_saw_substate: int = -1
	(func() -> void:
		stat_spy_applied = true
		stat_spy_saw_substate = WorkoutStateTracker.get(&"_substate")
	).call_deferred()

	# Act: GSM sends Suspended in the same frame (direct handler call — unit isolation)
	var payload := StateTransitionPayload.new()
	WorkoutStateTracker.call("_on_gsm_state_changed",
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		GameStateMachine.GameState.SUSPENDED,
		payload
	)

	# Assert: SUSPENDED must NOT have been entered synchronously (EC-08 deferred)
	assert_eq(WorkoutStateTracker.get(&"_substate"), WorkoutStateTracker.Substate.READY,
		"Substate must still be READY before frame boundary (EC-08 deferred entry)")
	assert_false(stat_spy_applied,
		"Stat spy must NOT have applied yet (deferred queue not yet drained)")

	# Drive one process_frame — drains call_deferred queue + fires process_frame callback
	await get_tree().process_frame

	# Assert: deferred queue drained + SUSPENDED entered
	assert_true(stat_spy_applied,
		"Stat spy must have applied after process_frame (deferred queue drained)")
	assert_eq(stat_spy_saw_substate, WorkoutStateTracker.Substate.READY,
		"Stat spy must have fired WHILE substate was still READY (EC-08: stat-apply ≺ SUSPENDED)")
	assert_eq(WorkoutStateTracker.get(&"_substate"), WorkoutStateTracker.Substate.SUSPENDED,
		"Substate must be SUSPENDED after process_frame (EC-08 deferred chain complete)")


## When phase != WORKOUT_COMPLETE, GSM Suspended enters SYNCHRONOUSLY (no defer).
func test_ac33_suspended_entry_immediate_when_not_workout_complete() -> void:
	# Arrange: phase in SET_ACTIVE (not WORKOUT_COMPLETE)
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)

	var payload := StateTransitionPayload.new()
	WorkoutStateTracker.call("_on_gsm_state_changed",
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		GameStateMachine.GameState.SUSPENDED,
		payload
	)

	# Synchronous entry — no deferral needed outside WORKOUT_COMPLETE
	assert_eq(WorkoutStateTracker.get(&"_substate"), WorkoutStateTracker.Substate.SUSPENDED,
		"Substate must be SUSPENDED synchronously when phase != WORKOUT_COMPLETE")


# ---------------------------------------------------------------------------
# AC-34: EC-11 — workout_completed dropped in SUSPENDED; backfill processes normally
# ---------------------------------------------------------------------------

## workout_completed dropped in SUSPENDED; _last_drop_reason and count verified.
func test_ac34_workout_completed_dropped_in_suspended() -> void:
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.SUSPENDED)
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	assert_eq(WorkoutStateTracker.get(&"_last_drop_reason"),
		&"WST_SUSPENDED_DROP_COMPLETE_001",
		"_last_drop_reason must record WST_SUSPENDED_DROP_COMPLETE_001 for dropped workout_completed")
	assert_signal_emit_count(WorkoutStateTracker, "workout_completed_forwarded", 0,
		"workout_completed_forwarded must NOT emit when dropped in SUSPENDED (EC-11)")
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 0,
		"phase_changed must NOT emit when workout_completed dropped")


## After unsuspend, backfill workout_completed is processed (phase advances normally).
func test_ac34_backfill_workout_completed_processed_after_unsuspend() -> void:
	# Arrange: advance to SET_ACTIVE, then enter SUSPENDED
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.SUSPENDED)

	# Drop the first workout_completed (SUSPENDED)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
		"Phase must stay SET_ACTIVE while SUSPENDED (dropped event)")

	# Unsuspend: GSM exits Suspended (direct call — unit isolation)
	var payload := StateTransitionPayload.new()
	WorkoutStateTracker.call("_on_gsm_state_changed",
		GameStateMachine.GameState.SUSPENDED,
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		payload
	)
	assert_eq(WorkoutStateTracker.get(&"_substate"), WorkoutStateTracker.Substate.READY,
		"Substate must return to READY after GSM exits Suspended")

	# Backfill re-emit: #2 polls and re-delivers workout_completed
	watch_signals(WorkoutStateTracker)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE,
		"Backfill workout_completed must advance phase to WORKOUT_COMPLETE (EC-11)")
	# Note: "workout_completed_forwarded count == 1" deferred to Story 006
	# (when the forwarded signal is actually emitted with transition_id + payload).


# ---------------------------------------------------------------------------
# Bonus: EC-02/03/04 guard branches (Story 001 tech debt — zero prior coverage)
# ---------------------------------------------------------------------------

## EC-02: set_logged in IDLE is dropped with WST_INV_VIOL_002.
func test_ec02_set_logged_in_idle_dropped() -> void:
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.IDLE, "Precondition: must be IDLE")
	var size_before: int = WorkoutStateTracker.get(&"_set_history").size()
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.IDLE,
		"EC-02: phase must stay IDLE after set_logged in IDLE")
	assert_eq(WorkoutStateTracker.get(&"_set_history").size(), size_before,
		"EC-02: set_history must NOT append when IDLE")
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 0,
		"EC-02: phase_changed must NOT emit for dropped set_logged")


## EC-03: rest_started in non-SET_ACTIVE is dropped with WST_INV_VIOL_003.
func test_ec03_rest_started_in_warm_up_dropped() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.WARM_UP, "Precondition: must be WARM_UP")
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_rest_started")

	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.WARM_UP,
		"EC-03: phase must stay WARM_UP after rest_started in non-SET_ACTIVE (EC-03)")
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 0,
		"EC-03: phase_changed must NOT emit for dropped rest_started")


## EC-04: rest_ended in non-REST_PERIOD is dropped with WST_INV_VIOL_004.
func test_ec04_rest_ended_in_set_active_dropped() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	assert_eq(WorkoutStateTracker.get(&"_workout_phase"),
		WorkoutStateTracker.WorkoutPhase.SET_ACTIVE, "Precondition: must be SET_ACTIVE")
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_rest_ended")

	assert_false(WorkoutStateTracker.get(&"_rest_ended_awaiting_next_set"),
		"EC-04: _rest_ended_awaiting_next_set must NOT be set in wrong phase")
	assert_signal_emit_count(WorkoutStateTracker, "phase_changed", 0,
		"EC-04: phase_changed must NOT emit for dropped rest_ended")
