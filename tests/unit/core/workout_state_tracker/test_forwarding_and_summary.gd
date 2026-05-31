# WorkoutStateTracker — Story 006 workout_completed Forwarding + WorkoutSummaryRO Tests
#
# Coverage:
#   AC-07 — 6 forwarded signals (Rule 10 strict order + poll_* NOT forwarded)
#   AC-15 — total_volume frozen at seal (CF-5); late set_logged dropped
#   AC-21 — Formula 4 total_volume + CF-2 final_set_progress at workout_completed
#   AC-24 — CF-4 set_history append-only prefix fuzz (50 events)
#   AC-25 — CF-5 stress: 20 late set_logged after seal → total_volume unchanged
#   AC-37 — EC-30 tombstone dedup (ADR-RATIFICATION-GATED — marked pending)
extends GutTest


func before_each() -> void:
	await get_tree().process_frame
	WorkoutStateTracker.set(&"_workout_phase", WorkoutStateTracker.WorkoutPhase.IDLE)
	WorkoutStateTracker.get(&"_set_history").clear()
	WorkoutStateTracker.set(&"_rest_ended_awaiting_next_set", false)
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.READY)
	WorkoutStateTracker.set(&"_is_frozen", false)
	WorkoutStateTracker.set(&"_last_drop_reason", &"")
	WorkoutStateTracker.set(&"_pending_suspended_entry", false)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)
	WorkoutStateTracker.set(&"_set_progress_is_estimated", true)
	WorkoutStateTracker.set(&"_historical_avg_sets", 0.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 0.0)
	WorkoutStateTracker.set(&"_planned_total_sets", -1)
	WorkoutStateTracker.set(&"_planned_reps_per_set", -1)
	WorkoutStateTracker.set(&"_current_workout_id", "wst-test-006")
	WorkoutStateTracker.set(&"_cached_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_previous_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_dominant_class_last_change_ms", 0)
	WorkoutStateTracker.set(&"_time_source", null)
	WorkoutStateTracker.get(&"_completed_exercises").clear()
	WorkoutStateTracker.set(&"_last_snapshot", null)
	WorkoutStateTracker.set(&"_last_summary", null)
	WorkoutStateTracker.set(&"_last_workout_transition_id", "")


# ---------------------------------------------------------------------------
# AC-07: 6 forwarded signals + emission order + poll_* NOT forwarded
# ---------------------------------------------------------------------------

## workout_started_forwarded emitted on workout_started.
func test_ac07_workout_started_forwarded_emitted() -> void:
	watch_signals(WorkoutStateTracker)
	WorkoutStateTracker.call("_on_workout_started")
	assert_signal_emitted(WorkoutStateTracker, "workout_started_forwarded",
		"AC-07: workout_started_forwarded must emit on workout_started")


## workout_summary_available emitted BEFORE workout_completed_forwarded (Rule 10 strict order).
func test_ac07_emission_order_summary_before_forwarded() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)
	watch_signals(WorkoutStateTracker)

	var emission_order: Array[String] = []
	WorkoutStateTracker.workout_summary_available.connect(
		func(_s: WorkoutSummaryRO) -> void: emission_order.append("summary_available"),
		CONNECT_ONE_SHOT
	)
	WorkoutStateTracker.workout_completed_forwarded.connect(
		func(_t: int, _id: String) -> void: emission_order.append("completed_forwarded"),
		CONNECT_ONE_SHOT
	)
	WorkoutStateTracker.phase_changed.connect(
		func(_f: int, _to: int) -> void:
			if _to == WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE:
				emission_order.append("phase_changed_to_wc"),
		CONNECT_ONE_SHOT
	)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	# Rule 10 strict order: phase_changed ≺ summary_available ≺ completed_forwarded
	assert_eq(emission_order.size(), 3,
		"AC-07: must have exactly 3 ordered emissions at completion")
	assert_eq(emission_order[0], "phase_changed_to_wc",
		"AC-07: phase_changed must fire FIRST (Rule 10)")
	assert_eq(emission_order[1], "summary_available",
		"AC-07: workout_summary_available must fire SECOND (Rule 10)")
	assert_eq(emission_order[2], "completed_forwarded",
		"AC-07: workout_completed_forwarded must fire THIRD (Rule 16 NEVER #12)")


## workout_completed_forwarded carries non-empty transition_id.
func test_ac07_completed_forwarded_has_transition_id() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	assert_signal_emitted(WorkoutStateTracker, "workout_completed_forwarded",
		"AC-07: workout_completed_forwarded must emit")
	var params: Array = get_signal_parameters(WorkoutStateTracker, "workout_completed_forwarded")
	assert_eq(params[0], 1748284800, "AC-07: completed_at must match input")
	assert_ne(params[1], "", "AC-07: transition_id must be non-empty (from GSM)")


## poll_failed and poll_recovered NOT forwarded as signals (AC-07 Rule 1).
func test_ac07_poll_signals_not_forwarded() -> void:
	# AC-07 structural assertion: no poll_*_forwarded signals must exist on WST
	assert_false(WorkoutStateTracker.has_signal("poll_failed_forwarded"),
		"AC-07: poll_failed_forwarded signal must NOT exist — poll_failed is internally consumed")
	assert_false(WorkoutStateTracker.has_signal("poll_recovered_forwarded"),
		"AC-07: poll_recovered_forwarded signal must NOT exist — poll_recovered is internally consumed")

	# Behavioral assertion: calling the handlers produces no forwarded signal emissions
	watch_signals(WorkoutStateTracker)
	WorkoutStateTracker.call("_on_poll_failed", &"network")
	WorkoutStateTracker.call("_on_poll_recovered")

	assert_signal_emit_count(WorkoutStateTracker, "workout_started_forwarded", 0,
		"AC-07: poll_* must NOT trigger workout_started_forwarded")
	assert_signal_emit_count(WorkoutStateTracker, "workout_completed_forwarded", 0,
		"AC-07: poll_* must NOT trigger workout_completed_forwarded")
	assert_signal_emit_count(WorkoutStateTracker, "workout_summary_available", 0,
		"AC-07: poll_* must NOT trigger workout_summary_available")
	# Verify poll_failed/recovered are still internally consumed correctly
	assert_false(WorkoutStateTracker.get(&"_is_frozen"),
		"After poll_failed + poll_recovered: _is_frozen must be false (correctly processed internally)")


# ---------------------------------------------------------------------------
# AC-15: total_volume frozen at seal (CF-5)
# ---------------------------------------------------------------------------

## total_volume frozen at seal; late set_logged after workout_completed is dropped.
func test_ac15_total_volume_frozen_after_seal() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	# Log sets that produce total_volume = 5000 (fake: use set_progress seam + manual history)
	# 50 sets × 100kg × 1rep = 5000
	for i in range(50):
		WorkoutStateTracker.call("_on_set_logged", &"bench_press", 1, 100.0)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	var summary: WorkoutSummaryRO = WorkoutStateTracker.get(&"_last_summary")
	assert_not_null(summary, "Precondition: _last_summary must be set after workout_completed")
	var volume_at_seal: float = summary.total_volume

	# Late set_logged after seal (WORKOUT_COMPLETE phase)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 60.0)  # EC-32: dropped

	assert_eq(summary.total_volume, volume_at_seal,
		"AC-15: WorkoutSummaryRO.total_volume must be frozen at seal — late set_logged must not change it")


# ---------------------------------------------------------------------------
# AC-21: Formula 4 total_volume + CF-2 final_set_progress
# ---------------------------------------------------------------------------

## WorkoutSummaryRO.total_volume == 4300.0 (Formula 4) + final_set_progress == 0.87 (CF-2).
func test_ac21_formula4_total_volume_and_cf2_final_set_progress() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	# 5 sets × 100kg × 5reps = 2500
	for i in range(5):
		WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 100.0)
	# 3 sets × 120kg × 5reps = 1800
	for i in range(3):
		WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 120.0)
	# total_volume = 2500 + 1800 = 4300

	# Inject final_set_progress = 0.87 (simulating Formula 1 result)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.87)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	var summary: WorkoutSummaryRO = WorkoutStateTracker.get(&"_last_summary")
	assert_not_null(summary)
	assert_almost_eq(summary.total_volume, 4300.0, 0.01,
		"AC-21: Formula 4 total_volume must be 4300.0 (2500 bench + 1800 squat)")
	assert_almost_eq(summary.final_set_progress, 0.87, 0.001,
		"AC-21: CF-2 final_set_progress must capture _cached_set_progress at seal time")


## Edge: bodyweight set (weight=0.0) contributes 0 to total_volume.
func test_ac21_bodyweight_set_contributes_zero() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 10, 60.0)   # 600
	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 0.0)           # 0 (bodyweight)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	var summary: WorkoutSummaryRO = WorkoutStateTracker.get(&"_last_summary")
	assert_not_null(summary)
	assert_almost_eq(summary.total_volume, 600.0, 0.01,
		"AC-21 edge: bodyweight set (weight=0) must contribute 0 to total_volume")


# ---------------------------------------------------------------------------
# AC-24: CF-4 append-only prefix consistency fuzz
# ---------------------------------------------------------------------------

## 50 set_logged: at every step, set_history[0..k-1] is prefix-consistent (no mutation).
func test_ac24_set_history_prefix_consistency_fuzz() -> void:
	WorkoutStateTracker.call("_on_workout_started")

	var snapshots: Array[Array] = []
	for i in range(50):
		WorkoutStateTracker.call("_on_set_logged", &"bench_press", i + 1, 50.0)
		# Deep-copy current set_history for comparison
		var current_history: Array = WorkoutStateTracker.get(&"_set_history")
		snapshots.append(current_history.duplicate(true))

	# Verify prefix invariant: snapshot[i][0..i] == snapshot[j][0..i] for all j > i
	for i in range(snapshots.size() - 1):
		var prefix_at_i: Array = snapshots[i]
		var later_snapshot: Array = snapshots[i + 1]
		for k in range(prefix_at_i.size()):
			assert_eq(later_snapshot[k], prefix_at_i[k],
				"AC-24 CF-4: set_history[%d] must be identical in snapshots at step %d and %d" \
				% [k, i, i + 1])


# ---------------------------------------------------------------------------
# AC-25: CF-5 stress — 20 late set_logged after seal
# ---------------------------------------------------------------------------

## 20 late set_logged after workout_completed → total_volume unchanged, 20 drops.
func test_ac25_late_set_logged_stress_total_volume_unchanged() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 10, 50.0)  # volume = 500
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	var summary: WorkoutSummaryRO = WorkoutStateTracker.get(&"_last_summary")
	var volume_at_seal: float = summary.total_volume
	assert_almost_eq(volume_at_seal, 500.0, 0.01,
		"Precondition: total_volume at seal must be 500.0")

	# 20 late set_logged (EC-32: dropped)
	for i in range(20):
		WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 60.0)

	# total_volume must be unchanged
	assert_almost_eq(summary.total_volume, volume_at_seal, 0.01,
		"AC-25: WorkoutSummaryRO.total_volume must be unchanged after 20 late set_logged (CF-5)")


# ---------------------------------------------------------------------------
# AC-37: EC-30 tombstone dedup (ADR-RATIFICATION-GATED)
# ---------------------------------------------------------------------------

## Duplicate transition_id: pending until ADR-0006 Contract 2 ratified + acquire_transition_id DI seam added.
## Bug WST-006-01: if the dedup triggers, _finalize_workout_idle is still scheduled (fixed in story-006 review).
## DEFERRED: requires inject seam for acquire_transition_id (currently a direct GSM call with no mock path).
## When unblocked: verify dedup drops signals, logs WST_TXN_COLLIDE_001, then FSM auto-transitions to IDLE.
func test_ac37_duplicate_transition_id_dropped() -> void:
	pending("AC-37 ADR-RATIFICATION-GATED — pending ADR-0006 Contract 2 tombstone finalization + acquire_transition_id DI seam")


## WorkoutSummaryRO has non-empty transition_id after normal workout_completed.
func test_ac37_summary_transition_id_non_empty_after_normal_completion() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	var summary: WorkoutSummaryRO = WorkoutStateTracker.get(&"_last_summary")
	assert_not_null(summary)
	assert_ne(summary.transition_id, "",
		"AC-37: WorkoutSummaryRO.transition_id must be non-empty after normal completion")
