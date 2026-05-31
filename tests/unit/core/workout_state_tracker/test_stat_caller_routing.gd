# WorkoutStateTracker — Story 007 Stat Caller Routing + Delta Queue Tests
#
# Coverage:
#   AC-11 — class→stat routing: bench_press→STR, squat→VIT, row→DEX; UNKNOWN→zero invocations
#           source_key format; frozen window guard
#   AC-39 — EC-29: FIFO queue overflow (cap 100); wst_queue_overflow signal; drain on Stat.ready
extends GutTest


## Fake StatSystem double that records apply_stat_delta calls.
## Untyped (per project DI convention) — implements duck-typed API.
class FakeStatSystem:
	## Whether the stat system is "READY" for this test.
	var is_ready: bool = true
	## Records of all apply_stat_delta calls in order.
	var calls: Array[Dictionary] = []
	## Signal mirroring StatSystem.ready (used to drain the pending queue).
	signal ready

	func get_substate() -> int:
		# Returns StatSystem.Substate.READY (1) or INITIALISING (0)
		return 1 if is_ready else 0

	func apply_stat_delta(stat_id: StringName, source: int, delta: float) -> bool:
		calls.append({"stat_id": stat_id, "source": source, "delta": delta})
		return true

	func has_method(method_name: String) -> bool:
		return method_name == "get_substate" or method_name == "apply_stat_delta"

	func clear_calls() -> void:
		calls.clear()


var _fake_stat: FakeStatSystem


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
	WorkoutStateTracker.set(&"_current_workout_id", "wst-test-007")
	WorkoutStateTracker.set(&"_cached_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_previous_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_dominant_class_last_change_ms", 0)
	WorkoutStateTracker.set(&"_time_source", null)
	WorkoutStateTracker.get(&"_completed_exercises").clear()
	WorkoutStateTracker.set(&"_last_snapshot", null)
	WorkoutStateTracker.set(&"_last_summary", null)
	WorkoutStateTracker.set(&"_last_workout_transition_id", "")
	# Story 007: inject fake stat system + reset pending queue
	_fake_stat = FakeStatSystem.new()
	WorkoutStateTracker.set(&"_stat_system", _fake_stat)
	WorkoutStateTracker.get(&"_pending_stat_deltas").clear()
	WorkoutStateTracker.set(&"_stat_delta_overflow_count", 0)


func after_each() -> void:
	# Restore real StatSystem reference (prevents cross-suite null-stat pollution).
	# NOT null — null would leave _route_stat_delta buffering instead of dispatching for
	# any subsequent test suite that doesn't inject its own _stat_system.
	WorkoutStateTracker.set(&"_stat_system", StatSystem)


# ---------------------------------------------------------------------------
# AC-11: class→stat routing (Rule 6 + Rule 13)
# ---------------------------------------------------------------------------

## bench_press (STRIKE) → apply_stat_delta(STR, 480.0, VOLUME_TICK, source_key).
func test_ac11_bench_press_routes_to_str() -> void:
	WorkoutStateTracker.call("_on_workout_started")

	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	assert_eq(_fake_stat.calls.size(), 1,
		"AC-11: bench_press must produce exactly 1 apply_stat_delta call")
	var call: Dictionary = _fake_stat.calls[0]
	assert_eq(call["stat_id"], StatSystem.StatId.STR,
		"AC-11: bench_press → STR (STRIKE class)")
	assert_almost_eq(call["delta"], 480.0, 0.001,
		"AC-11: delta == reps × weight == 8 × 60.0 == 480.0")
	assert_eq(call["source"], StatSystem.StatSource.VOLUME_TICK,
		"AC-11: source must be VOLUME_TICK")


## row (CONTROL) → apply_stat_delta(DEX, 480.0, VOLUME_TICK).
func test_ac11_row_routes_to_dex() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 60.0)

	assert_eq(_fake_stat.calls.size(), 1,
		"AC-11: row must produce exactly 1 apply_stat_delta call")
	assert_eq(_fake_stat.calls[0]["stat_id"], StatSystem.StatId.DEX,
		"AC-11: row → DEX (CONTROL class)")
	assert_almost_eq(_fake_stat.calls[0]["delta"], 480.0, 0.001)


## squat (MOBILITY) → apply_stat_delta(VIT, 480.0, VOLUME_TICK).
func test_ac11_squat_routes_to_vit() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 60.0)

	assert_eq(_fake_stat.calls.size(), 1,
		"AC-11: squat must produce exactly 1 apply_stat_delta call")
	assert_eq(_fake_stat.calls[0]["stat_id"], StatSystem.StatId.VIT,
		"AC-11: squat → VIT (MOBILITY class)")


## UNKNOWN exercise → apply_stat_delta NEVER called (invocation count == 0).
func test_ac11_unknown_exercise_zero_invocations() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"deadlift", 8, 100.0)  # unmapped → UNKNOWN

	assert_eq(_fake_stat.calls.size(), 0,
		"AC-11: UNKNOWN exercise must produce ZERO apply_stat_delta calls (Rule 6 skip)")


## source_key format: "%s_set_%d" % [workout_id, set_index].
## Does NOT call _on_workout_started() — that regenerates _current_workout_id.
## Instead sets phase manually to preserve the known workout_id from before_each.
func test_ac11_source_key_stored_in_pending_with_correct_format() -> void:
	_fake_stat.is_ready = false
	# Set phase to SET_ACTIVE manually (skipping _on_workout_started which would replace workout_id)
	WorkoutStateTracker.set(&"_workout_phase", WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)
	# _current_workout_id is "wst-test-007" from before_each (not overwritten since no _on_workout_started)

	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	var pending: Array = WorkoutStateTracker.get(&"_pending_stat_deltas")
	assert_eq(pending.size(), 1, "Precondition: must have 1 pending entry")
	var source_key: String = pending[0].get("source_key", "")
	# source_key format: "wst-test-007_set_1" (known workout_id + "_set_" + set_index)
	assert_eq(source_key, "wst-test-007_set_1",
		"AC-11: source_key must be exactly \"%s_set_%d\" format with known workout_id and set_index=1"
		% ["wst-test-007", 1])


## Null stat system: delta is buffered (not dispatched) without crashing.
func test_ac11_null_stat_system_buffers_without_crash() -> void:
	WorkoutStateTracker.set(&"_stat_system", null)
	WorkoutStateTracker.set(&"_workout_phase", WorkoutStateTracker.WorkoutPhase.SET_ACTIVE)

	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	assert_eq(WorkoutStateTracker.get(&"_pending_stat_deltas").size(), 1,
		"WST-007: null _stat_system must buffer delta without crash")

	# Restore for other tests in this function
	WorkoutStateTracker.set(&"_stat_system", _fake_stat)


## Frozen window: apply_stat_delta NOT called even for known exercise.
func test_ac11_frozen_gate_skips_stat_call() -> void:
	WorkoutStateTracker.set(&"_is_frozen", true)
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	assert_eq(_fake_stat.calls.size(), 0,
		"AC-11 frozen edge: apply_stat_delta must NOT be called when _is_frozen == true")


# ---------------------------------------------------------------------------
# AC-39: FIFO queue overflow (EC-29, cap 100)
# ---------------------------------------------------------------------------

## When Stat not READY + queue at cap + new set_logged: drop oldest (FIFO), emit wst_queue_overflow.
func test_ac39_queue_overflow_drops_oldest_and_emits_signal() -> void:
	_fake_stat.is_ready = false
	WorkoutStateTracker.call("_on_workout_started")

	# Fill queue to cap 100 with bench_press sets
	for i in range(100):
		WorkoutStateTracker.call("_on_set_logged", &"bench_press", i + 1, 10.0)

	var pending_before: Array = WorkoutStateTracker.get(&"_pending_stat_deltas")
	assert_eq(pending_before.size(), 100, "Precondition: queue must be at cap 100")

	# First entry has delta = (1 × 10.0) = 10.0 (i=0, reps=1)
	# Second entry has delta = (2 × 10.0) = 20.0 (i=1, reps=2) — this becomes new head after drop
	var first_entry_delta: float = pending_before[0].get("delta", -1.0)
	var second_entry_delta: float = pending_before[1].get("delta", -1.0)
	assert_almost_eq(first_entry_delta, 10.0, 0.001, "Precondition: first entry delta must be 10.0")
	assert_almost_eq(second_entry_delta, 20.0, 0.001, "Precondition: second entry delta must be 20.0")

	# 101st set_logged triggers overflow (reps=50, weight=10.0 → delta=500.0)
	watch_signals(WorkoutStateTracker)
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 50, 10.0)

	var pending_after: Array = WorkoutStateTracker.get(&"_pending_stat_deltas")
	assert_eq(pending_after.size(), 100,
		"AC-39: queue must stay at cap 100 after overflow (oldest dropped)")

	# FIFO: oldest (delta=10.0) was dropped; new head is second entry (delta=20.0)
	assert_almost_eq(pending_after[0].get("delta", -1.0), 20.0, 0.001,
		"AC-39: after dropping oldest (delta=10), new head must be delta=20 (FIFO order preserved)")
	# Newest entry (101st, delta=500) is at tail
	assert_almost_eq(pending_after[99].get("delta", -1.0), 500.0, 0.001,
		"AC-39: 101st entry (delta=50×10=500) must be at tail after FIFO overflow")

	assert_signal_emitted(WorkoutStateTracker, "wst_queue_overflow",
		"AC-39: wst_queue_overflow must emit on overflow")
	var sig_params: Array = get_signal_parameters(WorkoutStateTracker, "wst_queue_overflow")
	assert_eq(sig_params[0], 1,
		"AC-39: wst_queue_overflow payload must be dropped_count == 1 on first overflow")


## Queue drains in FIFO order when Stat.ready fires.
func test_ac39_queue_drains_on_stat_ready() -> void:
	_fake_stat.is_ready = false
	WorkoutStateTracker.call("_on_workout_started")

	# Buffer 3 calls (bench/row/squat)
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)  # STR, delta=300
	WorkoutStateTracker.call("_on_set_logged", &"row", 5, 50.0)           # DEX, delta=250
	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 80.0)         # VIT, delta=400

	assert_eq(WorkoutStateTracker.get(&"_pending_stat_deltas").size(), 3,
		"Precondition: 3 calls buffered")
	assert_eq(_fake_stat.calls.size(), 0,
		"Precondition: no calls dispatched yet (Stat not READY)")

	# Signal Stat is now READY — drain the queue
	_fake_stat.is_ready = true
	WorkoutStateTracker.call("_on_stat_system_ready")

	# All 3 calls dispatched in FIFO order
	assert_eq(_fake_stat.calls.size(), 3,
		"AC-39: all 3 buffered calls must dispatch on Stat.ready")
	assert_eq(_fake_stat.calls[0]["stat_id"], StatSystem.StatId.STR,
		"AC-39: first dispatched must be STR (bench_press, FIFO order)")
	assert_eq(_fake_stat.calls[1]["stat_id"], StatSystem.StatId.DEX,
		"AC-39: second dispatched must be DEX (row)")
	assert_eq(_fake_stat.calls[2]["stat_id"], StatSystem.StatId.VIT,
		"AC-39: third dispatched must be VIT (squat)")
	assert_eq(WorkoutStateTracker.get(&"_pending_stat_deltas").size(), 0,
		"AC-39: pending queue must be empty after drain")
