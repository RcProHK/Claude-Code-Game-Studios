# WorkoutStateTracker — Story 005 Read-Only Query API + workout_id Isolation Tests
#
# Coverage:
#   AC-05 — 5 public read-only getters + WorkoutSnapshotRO immutability + no set_* methods
#   AC-09 — workout_id lifecycle isolation (set_history + completed_exercises reset on new workout)
#   AC-14 — get_completed_exercises_count() returns DISTINCT count (not set count)
#   AC-30 — CI-5 distinct count stress (100 sets from 10-id pool, seeded fuzz)
extends GutTest

const FUZZ_SEED: int = 137  # Per QA test spec


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
	WorkoutStateTracker.set(&"_current_workout_id", "")
	WorkoutStateTracker.set(&"_cached_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_previous_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_dominant_class_last_change_ms", 0)
	WorkoutStateTracker.set(&"_time_source", null)
	# Story 005 vars
	WorkoutStateTracker.get(&"_completed_exercises").clear()
	WorkoutStateTracker.set(&"_last_snapshot", null)


# ---------------------------------------------------------------------------
# AC-05: 5 read-only getters + WorkoutSnapshotRO immutability
# ---------------------------------------------------------------------------

## All 5 getters callable without error and return expected default values.
func test_ac05_all_five_getters_callable_return_defaults() -> void:
	# All 5 getters must be callable without error
	var phase: int = WorkoutStateTracker.get_current_phase()
	var dom_class: int = WorkoutStateTracker.get_dominant_ability_class()
	var set_prog: float = WorkoutStateTracker.get_set_progress()
	var ex_count: int = WorkoutStateTracker.get_completed_exercises_count()
	var snapshot: WorkoutSnapshotRO = WorkoutStateTracker.get_workout_snapshot()

	assert_eq(phase, WorkoutStateTracker.WorkoutPhase.IDLE,
		"AC-05: get_current_phase() must return IDLE as default")
	assert_eq(dom_class, AbilitySystem.AbilityClass.UNKNOWN,
		"AC-05: get_dominant_ability_class() must return UNKNOWN as default")
	assert_almost_eq(set_prog, 0.0, 0.001,
		"AC-05: get_set_progress() must return 0.0 as default")
	assert_eq(ex_count, 0,
		"AC-05: get_completed_exercises_count() must return 0 with no exercises logged")
	assert_not_null(snapshot,
		"AC-05: get_workout_snapshot() must return a non-null WorkoutSnapshotRO")


## WST autoload has no script-authored set_*/mutate_*/force_* methods.
## Uses get_script().get_script_method_list() to check only WST-authored methods —
## NOT inherited Node/Object built-ins (set_deferred, set_meta, etc.).
func test_ac05_no_public_setter_methods_on_wst() -> void:
	var script_method_list: Array = WorkoutStateTracker.get_script().get_script_method_list()
	var offending: Array[String] = []
	for method_info: Dictionary in script_method_list:
		var method_name: String = method_info.get("name", "")
		if method_name.begins_with("set_") or method_name.begins_with("mutate_") \
				or method_name.begins_with("force_"):
			offending.append(method_name)
	assert_eq(offending.size(), 0,
		"AC-05: WST script must have no set_*/mutate_*/force_* methods (closed-API). Found: %s" % str(offending))


## WorkoutSnapshotRO is immutable after seal() — mutation attempt is blocked.
func test_ac05_workout_snapshot_immutable_after_seal() -> void:
	var snap: WorkoutSnapshotRO = WorkoutStateTracker.get_workout_snapshot()
	var original_phase: int = snap.current_phase

	# Attempt to mutate a field — should be blocked (push_error, value unchanged)
	snap.current_phase = 999

	assert_eq(snap.current_phase, original_phase,
		"AC-05: WorkoutSnapshotRO.current_phase must be unchanged after mutation attempt")


## WorkoutSnapshotRO reflects live WST state at time of call.
func test_ac05_snapshot_reflects_current_state() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.set(&"_cached_set_progress", 0.5)
	WorkoutStateTracker.set(&"_is_frozen", true)

	var snap: WorkoutSnapshotRO = WorkoutStateTracker.get_workout_snapshot()

	assert_eq(snap.current_phase, WorkoutStateTracker.WorkoutPhase.WARM_UP,
		"AC-05: snapshot.current_phase must reflect live WARM_UP phase")
	assert_almost_eq(snap.set_progress, 0.5, 0.001,
		"AC-05: snapshot.set_progress must reflect live cached value")
	assert_true(snap.is_stale_due_to_poll_failure,
		"AC-05: snapshot.is_stale_due_to_poll_failure must reflect _is_frozen")


# ---------------------------------------------------------------------------
# AC-09: workout_id lifecycle isolation (Rule 11.1)
# ---------------------------------------------------------------------------

## New workout_started generates a new workout_id different from the prior one.
func test_ac09_new_workout_generates_different_id() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	var id_w1: String = WorkoutStateTracker.get_active_workout_id()
	assert_ne(id_w1, "", "First workout must have non-empty workout_id")

	# Complete W1 then start W2
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	await get_tree().process_frame  # Drain _finalize_workout_idle deferred

	WorkoutStateTracker.call("_on_workout_started")
	var id_w2: String = WorkoutStateTracker.get_active_workout_id()
	assert_ne(id_w2, "", "Second workout must have non-empty workout_id")
	assert_ne(id_w2, id_w1, "AC-09: W2 workout_id must differ from W1 (no cross-contamination)")


## set_history resets empty on new workout_started.
func test_ac09_set_history_resets_on_new_workout() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)
	assert_eq(WorkoutStateTracker.get(&"_set_history").size(), 2,
		"Precondition: W1 must have 2 set_history entries")

	# Start new workout (after completing the first)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	await get_tree().process_frame
	WorkoutStateTracker.call("_on_workout_started")

	assert_eq(WorkoutStateTracker.get(&"_set_history").size(), 0,
		"AC-09: set_history must reset to empty on new workout_started")


## _completed_exercises resets on new workout_started.
func test_ac09_completed_exercises_resets_on_new_workout() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 2,
		"Precondition: W1 must have 2 distinct exercises")

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	await get_tree().process_frame
	WorkoutStateTracker.call("_on_workout_started")

	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 0,
		"AC-09: _completed_exercises must reset to 0 on new workout_started")


## W2 data does not contaminate W1-era distinct count (isolation check).
## Note: AC-09 also specifies "W1 WorkoutSummaryRO.transition_id preserved" — that half
## is DEFERRED to Story 006 (WorkoutSummaryRO does not exist yet). Story 005 covers
## workout_id, set_history, and completed_exercises isolation only (AC-09a).
func test_ac09_no_cross_contamination_between_workouts() -> void:
	# W1: 3 distinct exercises
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 3,
		"W1 must have 3 distinct exercises before completion")

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)
	await get_tree().process_frame

	# W2: different exercises
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 70.0)

	# W2 count should be 1 (only bench_press), not 4 from W1
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 1,
		"AC-09: W2 distinct count must be independent of W1 (no cross-contamination)")


# ---------------------------------------------------------------------------
# AC-14: get_completed_exercises_count() returns DISTINCT count
# ---------------------------------------------------------------------------

## 5 set_logged with {E1, E1, E2, E1, E3} → count == 3 (distinct), not 5.
func test_ac14_distinct_count_not_set_count() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	# E1 logged 3×, E2 once, E3 once → 3 distinct
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)  # E1
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)  # E1 (duplicate)
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)           # E2
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)  # E1 (duplicate)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)         # E3

	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 3,
		"AC-14: 5 set_logged with {E1,E1,E2,E1,E3} must return 3 (distinct), not 5 (set count)")


## Edge: 0 sets → count 0.
func test_ac14_zero_sets_count_zero() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 0,
		"AC-14 edge: 0 sets must return count 0")


## Edge: single exercise logged 5× → count 1.
func test_ac14_single_exercise_repeated_count_one() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	for i in range(5):
		WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 1,
		"AC-14 edge: same exercise ×5 must return count 1 (distinct)")


# ---------------------------------------------------------------------------
# AC-30: CI-5 distinct count fuzz (100 sets from 10-id pool, seeded)
# ---------------------------------------------------------------------------

## CI-5 explicit: an UNKNOWN-classified exercise still contributes to distinct count.
## Guards against a future regression that mistakenly filters by AbilityClass.
func test_ci5_unmapped_exercise_still_counts_distinct() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	# deadlift is unmapped (UNKNOWN class) but must still count as distinct exercise
	WorkoutStateTracker.call("_on_set_logged", &"deadlift", 5, 100.0)

	assert_eq(WorkoutStateTracker.get_dominant_ability_class(), AbilitySystem.AbilityClass.UNKNOWN,
		"Precondition: deadlift must be classified UNKNOWN")
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 1,
		"CI-5: UNKNOWN-classified exercise must still increment distinct count (not filtered)")


## 100 sets from 10-id pool → count == 10; never exceeds pool cardinality.
func test_ac30_distinct_count_stress_seeded_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FUZZ_SEED

	var exercise_pool: Array[StringName] = [
		&"bench_press", &"row", &"squat", &"deadlift", &"overhead_press",
		&"bicep_curl", &"tricep_pushdown", &"lat_pulldown", &"cable_fly", &"leg_press",
	]  # Pool of exactly 10 distinct IDs

	WorkoutStateTracker.call("_on_workout_started")

	var seen_ids: Dictionary = {}
	for i in range(100):
		var idx: int = rng.randi_range(0, exercise_pool.size() - 1)
		var ex_id: StringName = exercise_pool[idx]
		seen_ids[ex_id] = true
		WorkoutStateTracker.call("_on_set_logged", ex_id, 8, 60.0)

		# Count must never exceed distinct IDs seen so far
		var current_count: int = WorkoutStateTracker.get_completed_exercises_count()
		assert_true(current_count <= seen_ids.size(),
			"AC-30: count (%d) must never exceed seen distinct ids (%d) at step %d" \
			% [current_count, seen_ids.size(), i])

	# After 100 sets from 10-id pool: count must be exactly 10
	assert_eq(WorkoutStateTracker.get_completed_exercises_count(), 10,
		"AC-30: 100 sets from 10-id pool must yield count == 10 (== pool cardinality)")
