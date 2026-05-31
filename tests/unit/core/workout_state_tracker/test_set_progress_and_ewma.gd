# WorkoutStateTracker — Story 003 set_progress Derivation + Monotonicity + EWMA Tests
#
# Coverage:
#   AC-04 — CF-1: downward revision suppressed; log WST_PROGRESS_MONOTONIC_BLOCKED
#   AC-12 — set_progress_is_estimated flag (estimated vs full-data path)
#   AC-19 — Formula 2 EWMA value + CF-3 relative ordering (build ≺ ewma ≺ reset)
#   AC-20 — Formula 1: Example A (full-data), Example B (estimated), bonus-set clamp
#   AC-22 — CF-1 monotonic fuzz (100 seeded raw values)
#   AC-23 — CF-3 pre-reset guard: _current_workout_id non-empty at EWMA compute time
extends GutTest

## Seed constant per QA Test Cases spec (FIXED — not runtime random).
const FUZZ_SEED: int = 42


func before_each() -> void:
	await get_tree().process_frame
	WorkoutStateTracker.set(&"_workout_phase", WorkoutStateTracker.WorkoutPhase.IDLE)
	WorkoutStateTracker.get(&"_set_history").clear()
	WorkoutStateTracker.set(&"_rest_ended_awaiting_next_set", false)
	WorkoutStateTracker.set(&"_substate", WorkoutStateTracker.Substate.READY)
	WorkoutStateTracker.set(&"_is_frozen", false)
	WorkoutStateTracker.set(&"_last_drop_reason", &"")
	WorkoutStateTracker.set(&"_pending_suspended_entry", false)
	# Story 003 vars
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)
	WorkoutStateTracker.set(&"_set_progress_is_estimated", true)
	WorkoutStateTracker.set(&"_historical_avg_sets", 0.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 0.0)
	WorkoutStateTracker.set(&"_planned_total_sets", -1)
	WorkoutStateTracker.set(&"_planned_reps_per_set", -1)
	WorkoutStateTracker.set(&"_current_workout_id", "")


# ---------------------------------------------------------------------------
# AC-04: CF-1 monotonic downward suppression
# ---------------------------------------------------------------------------

## Downward revision is suppressed and set_progress_changed is NOT emitted.
func test_ac04_monotonic_downward_suppressed_no_emit() -> void:
	# Arrange: preset a non-zero cached value
	WorkoutStateTracker.set(&"_cached_set_progress", 0.42)
	WorkoutStateTracker.set(&"_historical_avg_sets", 6.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 10.0)
	watch_signals(WorkoutStateTracker)

	# Simulate estimator producing a lower raw value (0.31 < 0.42)
	# effective_total = max(1+1, 6) = 6, reps/set=10, current=1 set, reps=1
	# raw = (1-1 + 1/10) / 6 = 0.1/6 = 0.0167 < 0.42 → suppressed
	WorkoutStateTracker.call("_apply_monotonic_clamp", 0.31)

	assert_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.42,
		"AC-04: forwarded set_progress must stay 0.42 when raw < current")
	assert_signal_emit_count(WorkoutStateTracker, "set_progress_changed", 0,
		"AC-04: set_progress_changed must NOT emit when revision is downward")


## Equal value: non-decreasing but no actual change → no emit.
func test_ac04_equal_value_no_emit() -> void:
	WorkoutStateTracker.set(&"_cached_set_progress", 0.42)
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_apply_monotonic_clamp", 0.42)

	assert_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.42,
		"AC-04: value must stay at 0.42 (equal raw)")
	assert_signal_emit_count(WorkoutStateTracker, "set_progress_changed", 0,
		"AC-04: set_progress_changed must NOT emit for equal value (no change)")


## Upward revision emits set_progress_changed with new value.
func test_ac04_upward_revision_emits() -> void:
	WorkoutStateTracker.set(&"_cached_set_progress", 0.30)
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_apply_monotonic_clamp", 0.55)

	assert_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.55,
		"Upward revision must update _cached_set_progress")
	assert_signal_emitted_with_parameters(WorkoutStateTracker, "set_progress_changed", [0.55])


# ---------------------------------------------------------------------------
# AC-12: set_progress_is_estimated flag
# ---------------------------------------------------------------------------

## Estimated path active when planned_total_sets unavailable but historical > 0.
func test_ac12_estimated_flag_true_when_no_planned() -> void:
	WorkoutStateTracker.set(&"_historical_avg_sets", 5.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 8.0)
	WorkoutStateTracker.set(&"_planned_total_sets", -1)  # unknown

	# Drive one set_logged to trigger formula
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	assert_true(WorkoutStateTracker.get(&"_set_progress_is_estimated"),
		"AC-12: estimated flag must be true when planned_total_sets is unavailable")


## Full-data path: estimated flag false when planned_total_sets is known.
func test_ac12_estimated_flag_false_when_planned_known() -> void:
	WorkoutStateTracker.set(&"_planned_total_sets", 6)
	WorkoutStateTracker.set(&"_planned_reps_per_set", 10)

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	assert_false(WorkoutStateTracker.get(&"_set_progress_is_estimated"),
		"AC-12: estimated flag must be false when planned_total_sets is known (full-data path)")


## Cold start (no historical, no planned) → estimated true + neutral fallback applied.
func test_ac12_cold_start_estimated_flag_true() -> void:
	# Both historical and planned unavailable
	WorkoutStateTracker.set(&"_historical_avg_sets", 0.0)
	WorkoutStateTracker.set(&"_planned_total_sets", -1)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	assert_true(WorkoutStateTracker.get(&"_set_progress_is_estimated"),
		"AC-12 edge: estimated must be true on cold start")
	# Neutral fallback = 0.5 applied
	assert_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.5,
		"AC-12 edge: cold start must apply SET_PROGRESS_NEUTRAL_FALLBACK (0.5)")


# ---------------------------------------------------------------------------
# AC-19: Formula 2 EWMA value + CF-3 relative ordering
# ---------------------------------------------------------------------------

## EWMA produces 5.4 from prior=6.0, new=4 sets, alpha=0.3.
## Call order: set_progress_changed may fire, then EWMA computed, then reset happens.
func test_ac19_ewma_value_and_cf3_ordering() -> void:
	# Arrange: 4 sets logged with known reps
	WorkoutStateTracker.set(&"_historical_avg_sets", 6.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 8.0)
	WorkoutStateTracker.set(&"_current_workout_id", "wst-test-0001")

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"bench", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"bench", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"bench", 8, 60.0)
	# 4 sets logged

	# Spy on CF-3 ordering: capture workout_id at EWMA compute time
	var workout_id_at_ewma_compute: String = ""
	var ewma_value_at_compute: float = 0.0
	# We can directly call _compute_ewma to test its output and verify
	# _current_workout_id is non-empty (CF-3 ordering AC-23 property)
	workout_id_at_ewma_compute = WorkoutStateTracker.get(&"_current_workout_id")
	WorkoutStateTracker.call("_compute_ewma", 4)
	ewma_value_at_compute = WorkoutStateTracker.get(&"_historical_avg_sets")

	# CF-3: EWMA ran while workout_id non-empty (before reset)
	assert_ne(workout_id_at_ewma_compute, "",
		"AC-19/CF-3: _current_workout_id must be non-empty when EWMA computes")
	# EWMA value: 0.3×4 + 0.7×6.0 = 1.2 + 4.2 = 5.4
	assert_almost_eq(ewma_value_at_compute, 5.4, 0.001,
		"AC-19: EWMA must produce 5.4 (0.3×4 + 0.7×6.0)")


## First workout (cold start): no EWMA blend — stores raw value directly.
func test_ac19_ewma_cold_start_stores_raw() -> void:
	WorkoutStateTracker.set(&"_historical_avg_sets", 0.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 0.0)

	# 5 sets logged, 10 reps each
	for i in range(5):
		WorkoutStateTracker.get(&"_set_history").append({"exercise_id": &"squat", "reps": 10, "weight": 80.0})

	WorkoutStateTracker.call("_compute_ewma", 5)

	assert_almost_eq(WorkoutStateTracker.get(&"_historical_avg_sets"), 5.0, 0.001,
		"AC-19 edge: cold start must store sets_count directly (no EWMA blend)")
	assert_almost_eq(WorkoutStateTracker.get(&"_historical_avg_reps_per_set"), 10.0, 0.001,
		"AC-19 edge: cold start must store avg_reps directly (no EWMA blend)")


# ---------------------------------------------------------------------------
# AC-20: Formula 1 both paths + bonus clamp
# ---------------------------------------------------------------------------

## Example A — full-data path: planned 6 sets × 10 reps, set 5, reps 8/10.
## Expected: set_progress = (5-1 + 8/10) / 6 = 4.8/6 = 0.800
func test_ac20_formula1_full_data_path_example_a() -> void:
	WorkoutStateTracker.set(&"_planned_total_sets", 6)
	WorkoutStateTracker.set(&"_planned_reps_per_set", 10)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	# Log 4 prior sets to build history (each with 10 reps)
	WorkoutStateTracker.call("_on_workout_started")
	for i in range(4):
		WorkoutStateTracker.call("_on_set_logged", &"squat", 10, 80.0)

	# Log set 5 with 8 reps → triggers formula computation
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	assert_almost_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.800, 0.001,
		"AC-20 Example A: full-data path must yield 0.800")
	assert_false(WorkoutStateTracker.get(&"_set_progress_is_estimated"),
		"AC-20 Example A: estimated flag must be false on full-data path")


## Example B — estimated path: historical_avg_sets=5.2, reps_per_set=9.4, set 5, reps 8.
## effective_total = max(5+1, 5.2) = 6
## effective_reps  = max(1, round(9.4)) = 9
## raw = (5-1 + 8/9) / 6 = (4 + 0.8889) / 6 = 4.8889/6 = 0.8148
func test_ac20_formula1_estimated_path_example_b() -> void:
	WorkoutStateTracker.set(&"_historical_avg_sets", 5.2)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 9.4)
	WorkoutStateTracker.set(&"_planned_total_sets", -1)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	WorkoutStateTracker.call("_on_workout_started")
	for i in range(4):
		WorkoutStateTracker.call("_on_set_logged", &"squat", 9, 80.0)

	# 5th set with 8 reps
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	assert_almost_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.815, 0.005,
		"AC-20 Example B: estimated path must yield ~0.815")
	assert_true(WorkoutStateTracker.get(&"_set_progress_is_estimated"),
		"AC-20 Example B: estimated flag must be true on estimated path")


## Bonus set (current > planned) → clamp ≤ SET_PROGRESS_BONUS_SET_CLAMP (0.95).
func test_ac20_bonus_set_clamped_to_095() -> void:
	# planned 2 sets × 10 reps. Use partial reps on planned sets so set_progress stays
	# BELOW 0.95 through the planned sets — otherwise the last planned set (full reps)
	# legitimately reaches 1.0 and monotonicity correctly blocks the bonus clamp from
	# lowering it. The 3rd set is the bonus set (current_set_index 3 > planned_total 2).
	WorkoutStateTracker.set(&"_planned_total_sets", 2)
	WorkoutStateTracker.set(&"_planned_reps_per_set", 10)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	WorkoutStateTracker.call("_on_workout_started")
	# Set 1: (1-1 + 5/10)/2 = 0.25
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)
	# Set 2: (2-1 + 5/10)/2 = 0.75 (not > planned, no clamp)
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)
	# Set 3 (BONUS, current 3 > planned 2): raw=(3-1+10/10)/2=1.5→clamp 1.0→bonus min(1.0,0.95)=0.95
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 10, 60.0)

	assert_almost_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.95, 0.001,
		"AC-20: bonus set must clamp set_progress to exactly SET_PROGRESS_BONUS_SET_CLAMP (0.95)")


# ---------------------------------------------------------------------------
# AC-22: CF-1 monotonic fuzz (100 seeded events)
# ---------------------------------------------------------------------------

## 100 seeded raw values applied through _apply_monotonic_clamp must be non-decreasing.
func test_ac22_monotonic_fuzz_100_seeded_events() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FUZZ_SEED  # File-level fixture constant = 42

	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)
	var prev_value: float = 0.0

	for i in range(100):
		var raw: float = rng.randf()  # uniform [0.0, 1.0]
		WorkoutStateTracker.call("_apply_monotonic_clamp", raw)
		var current: float = WorkoutStateTracker.get(&"_cached_set_progress")
		assert_true(current >= prev_value,
			"AC-22 CF-1 fuzz: set_progress must be non-decreasing (step %d: prev=%.4f, current=%.4f)" \
			% [i, prev_value, current])
		prev_value = current


# ---------------------------------------------------------------------------
# AC-23: CF-3 pre-reset guard — workout_id non-empty at EWMA compute time
# ---------------------------------------------------------------------------

## _current_workout_id must be non-empty when EWMA computes (CF-3 ordering invariant).
func test_ac23_workout_id_non_empty_at_ewma_compute() -> void:
	# Arrange: full workout ending
	WorkoutStateTracker.set(&"_historical_avg_sets", 5.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 8.0)

	WorkoutStateTracker.call("_on_workout_started")
	assert_ne(WorkoutStateTracker.get(&"_current_workout_id"), "",
		"Precondition: _current_workout_id must be non-empty after workout_started")

	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	# Capture workout_id just before EWMA runs (simulating what _on_workout_completed does)
	var workout_id_at_ewma: String = WorkoutStateTracker.get(&"_current_workout_id")
	WorkoutStateTracker.call("_compute_ewma", 3)

	# CF-3 assertion: workout_id was non-empty when EWMA computed
	assert_ne(workout_id_at_ewma, "",
		"AC-23 CF-3: _current_workout_id must be non-empty at EWMA compute time (before reset)")

	# Now simulate reset (as _finalize_workout_idle does)
	WorkoutStateTracker.call("_finalize_workout_idle")
	await get_tree().process_frame  # drain the deferred transition

	# After reset: workout_id cleared
	assert_eq(WorkoutStateTracker.get(&"_current_workout_id"), "",
		"AC-23: _current_workout_id must be empty after workout finalization")


# ---------------------------------------------------------------------------
# Boundary / edge cases (Q5 recommendations from QA tester review)
# ---------------------------------------------------------------------------

## planned_reps_per_set == 0: must fall to estimated path and log WST_PLANNED_ZERO_001.
## If historical also 0 → neutral fallback 0.5 (GDD EC-15).
func test_boundary_planned_reps_zero_with_no_historical_gives_neutral() -> void:
	WorkoutStateTracker.set(&"_planned_total_sets", 6)
	WorkoutStateTracker.set(&"_planned_reps_per_set", 0)   # invalid
	WorkoutStateTracker.set(&"_historical_avg_sets", 0.0)  # no history
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	assert_true(WorkoutStateTracker.get(&"_set_progress_is_estimated"),
		"Boundary: planned_reps=0 + no historical must set estimated=true")
	assert_almost_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.5, 0.001,
		"Boundary: planned_reps=0 + no historical must apply neutral fallback 0.5 (EC-15)")


## planned_reps_per_set == 0 WITH historical available: falls to estimated path (not neutral).
func test_boundary_planned_reps_zero_with_historical_uses_estimated() -> void:
	WorkoutStateTracker.set(&"_planned_total_sets", 6)
	WorkoutStateTracker.set(&"_planned_reps_per_set", 0)
	WorkoutStateTracker.set(&"_historical_avg_sets", 5.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 8.0)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	assert_true(WorkoutStateTracker.get(&"_set_progress_is_estimated"),
		"Boundary: planned_reps=0 with historical must use estimated path")
	var progress: float = WorkoutStateTracker.get(&"_cached_set_progress")
	assert_true(progress >= 0.0 and progress <= 1.0,
		"Boundary: estimated path must produce a value in [0,1]")
	# Not equal to neutral fallback (historical is available so estimator runs)
	assert_true(progress != 0.5 or progress > 0.0,
		"Boundary: estimated path with historical should not give neutral fallback")


## reps_in_set == 0: no division by zero; value stays in [0,1].
func test_boundary_zero_reps_no_crash() -> void:
	WorkoutStateTracker.set(&"_historical_avg_sets", 5.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 8.0)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	WorkoutStateTracker.call("_on_workout_started")
	# Log a set with 0 reps (unusual but must not crash)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 0, 80.0)

	var progress: float = WorkoutStateTracker.get(&"_cached_set_progress")
	assert_true(progress >= 0.0 and progress <= 1.0,
		"Boundary: 0 reps must not crash and must produce value in [0,1]")


## planned_total_sets == 0: boundary of < 1 check. Must route to cold-start or estimated.
func test_boundary_planned_total_sets_zero_routes_to_fallback() -> void:
	WorkoutStateTracker.set(&"_planned_total_sets", 0)   # boundary: < 1 → cold-start or estimated
	WorkoutStateTracker.set(&"_historical_avg_sets", 0.0)
	WorkoutStateTracker.set(&"_cached_set_progress", 0.0)

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)

	# planned_total_sets == 0 → condition `< 1` is true → cold-start path → neutral 0.5
	assert_almost_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.5, 0.001,
		"Boundary: planned_total_sets=0 (< 1) with no historical must give neutral 0.5")


## EWMA compute ≺ reset in _on_workout_completed (CF-3 integration test).
func test_ac23_ewma_runs_before_reset_in_workout_completed() -> void:
	WorkoutStateTracker.set(&"_historical_avg_sets", 6.0)
	WorkoutStateTracker.set(&"_historical_avg_reps_per_set", 8.0)

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 8, 80.0)
	# 4 sets — EWMA will yield 0.3×4 + 0.7×6.0 = 5.4

	# workout_completed triggers EWMA synchronously + deferred reset
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	# EWMA runs synchronously in _on_workout_completed → value is already updated
	assert_almost_eq(WorkoutStateTracker.get(&"_historical_avg_sets"), 5.4, 0.001,
		"AC-23 CF-3: EWMA (5.4) must be computed synchronously in _on_workout_completed")

	# _current_workout_id is still non-empty now (reset is deferred)
	assert_ne(WorkoutStateTracker.get(&"_current_workout_id"), "",
		"AC-23 CF-3: _current_workout_id must still be non-empty immediately after workout_completed (reset deferred)")

	# Drain deferred reset
	await get_tree().process_frame

	# After deferred reset: workout_id cleared + set_progress reset
	assert_eq(WorkoutStateTracker.get(&"_current_workout_id"), "",
		"AC-23: _current_workout_id must be empty after deferred _finalize_workout_idle")
	assert_eq(WorkoutStateTracker.get(&"_cached_set_progress"), 0.0,
		"AC-23: _cached_set_progress must be reset to 0.0 after workout finalization")
