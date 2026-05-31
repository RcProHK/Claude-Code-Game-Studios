# WorkoutStateTracker — Story 004 dominant_class Derivation + Hysteresis + VS Stub Tests
#
# Coverage:
#   AC-10 — dominant_class change cooldown 30s (injectable time-source DI seam)
#   AC-13 — UNKNOWN honest return (CI-3); unmapped exercises never contribute to STRIKE
#   AC-18 — Formula 3 tiebreak walk (8-set example → STRIKE; 3-way tie → UNKNOWN)
#   AC-28 — CI-3 narrowed to #9 surface: signal spy never emits STRIKE as fallback
#   AC-43 — VS-tier stub: 3 in-stub correct; 17+ out-of-stub → UNKNOWN, zero hallucination
extends GutTest


## Injectable fake time source for cooldown tests.
## Tests set WorkoutStateTracker.set(&"_time_source", _fake_timer).
class FakeTimerMs:
	var now_ms: int = 0
	func get_now_ms() -> int:
		return now_ms


var _fake_timer: FakeTimerMs


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
	WorkoutStateTracker.set(&"_current_workout_id", "wst-test-001")
	# Story 004 vars
	WorkoutStateTracker.set(&"_cached_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_previous_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.set(&"_dominant_class_last_change_ms", 0)
	# Inject fake timer (clean state, time = 0)
	_fake_timer = FakeTimerMs.new()
	WorkoutStateTracker.set(&"_time_source", _fake_timer)


func after_each() -> void:
	# Remove fake timer to restore real time for other test suites
	WorkoutStateTracker.set(&"_time_source", null)


# ---------------------------------------------------------------------------
# AC-43: VS-tier stub classification (FR-2) — tested first as it's foundational
# ---------------------------------------------------------------------------

## In-stub exercises classified correctly.
func test_ac43_in_stub_exercises_classified_correctly() -> void:
	assert_eq(WorkoutStateTracker.call("_classify_exercise", &"bench_press"),
		AbilitySystem.AbilityClass.STRIKE,
		"bench_press must classify as STRIKE")
	assert_eq(WorkoutStateTracker.call("_classify_exercise", &"row"),
		AbilitySystem.AbilityClass.CONTROL,
		"row must classify as CONTROL")
	assert_eq(WorkoutStateTracker.call("_classify_exercise", &"squat"),
		AbilitySystem.AbilityClass.MOBILITY,
		"squat must classify as MOBILITY")


## All out-of-stub exercise_ids return UNKNOWN — zero hallucination.
func test_ac43_out_of_stub_returns_unknown_zero_hallucination() -> void:
	var out_of_stub_ids: Array = [
		&"deadlift", &"overhead_press", &"cable_fly", &"lat_pulldown",
		&"lunges", &"leg_press", &"bicep_curl", &"tricep_pushdown",
		&"plank", &"calf_raises", &"face_pull", &"dips",
		&"leg_extension", &"hip_thrust", &"cable_row", &"shoulder_press",
		&"unknown_exercise",
	]
	for exercise_id: StringName in out_of_stub_ids:
		assert_eq(
			WorkoutStateTracker.call("_classify_exercise", exercise_id),
			AbilitySystem.AbilityClass.UNKNOWN,
			"Out-of-stub exercise_id '%s' must return UNKNOWN (zero hallucination)" % exercise_id
		)


## Edge: empty StringName → UNKNOWN (no crash).
func test_ac43_empty_exercise_id_returns_unknown() -> void:
	assert_eq(WorkoutStateTracker.call("_classify_exercise", &""),
		AbilitySystem.AbilityClass.UNKNOWN,
		"Empty exercise_id must return UNKNOWN (no crash)")


# ---------------------------------------------------------------------------
# AC-13: UNKNOWN honest return (CI-3)
# ---------------------------------------------------------------------------

## Unmapped sets are excluded from all class tallies.
func test_ac13_unmapped_sets_excluded_from_tally() -> void:
	# All out-of-stub → set_counts all stay 0 → UNKNOWN
	for i in range(5):
		WorkoutStateTracker.get(&"_set_history").append({
			"exercise_id": &"deadlift", "reps": 8, "weight": 100.0
		})

	var result: int = WorkoutStateTracker.call("_compute_dominant_class")
	assert_eq(result, AbilitySystem.AbilityClass.UNKNOWN,
		"AC-13: full workout with only unmapped exercises must return UNKNOWN (not STRIKE)")


## Full workout all-UNKNOWN: get_dominant_ability_class() (via _cached) returns UNKNOWN.
func test_ac13_all_unknown_workout_cached_returns_unknown() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	for i in range(3):
		WorkoutStateTracker.call("_on_set_logged", &"deadlift", 8, 100.0)

	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.UNKNOWN,
		"AC-13: _cached_dominant_class must be UNKNOWN after all-UNKNOWN workout")


# ---------------------------------------------------------------------------
# AC-18: Formula 3 tiebreak walk (8-set example from GDD Section D)
# ---------------------------------------------------------------------------

## GDD Section D 8-set example: STRIKE=3, CONTROL=3, MOBILITY=2.
## Tiebreak walk finds STRIKE as last solo leader at prefix [0..5].
## Note: GDD uses "squat=STRIKE" semantically, but our stub maps squat→MOBILITY.
## Equivalent sequence using our stub: bench(S),row(C),bench(S),squat(M),row(C),bench(S),row(C),squat(M).
## Result: STRIKE:3, CONTROL:3, MOBILITY:2 — tiebreak at i=5 finds STRIKE solo.
func test_ac18_formula3_tiebreak_gdd_example_returns_strike() -> void:
	WorkoutStateTracker.get(&"_set_history").clear()
	var history: Array = WorkoutStateTracker.get(&"_set_history")
	# [0] bench=STRIKE, [1] row=CONTROL, [2] bench=STRIKE, [3] squat=MOBILITY,
	# [4] row=CONTROL,  [5] bench=STRIKE, [6] row=CONTROL,  [7] squat=MOBILITY
	# set_counts = {STRIKE:3, CONTROL:3, MOBILITY:2}
	history.append({"exercise_id": &"bench_press", "reps": 8, "weight": 60.0})  # [0] S
	history.append({"exercise_id": &"row",         "reps": 8, "weight": 50.0})  # [1] C
	history.append({"exercise_id": &"bench_press", "reps": 8, "weight": 60.0})  # [2] S
	history.append({"exercise_id": &"squat",       "reps": 8, "weight": 80.0})  # [3] M
	history.append({"exercise_id": &"row",         "reps": 8, "weight": 50.0})  # [4] C
	history.append({"exercise_id": &"bench_press", "reps": 8, "weight": 60.0})  # [5] S ← solo leader at [0..5]
	history.append({"exercise_id": &"row",         "reps": 8, "weight": 50.0})  # [6] C → tie restored
	history.append({"exercise_id": &"squat",       "reps": 8, "weight": 80.0})  # [7] M

	# Verify the tiebreak
	var result: int = WorkoutStateTracker.call("_compute_dominant_class")
	assert_eq(result, AbilitySystem.AbilityClass.STRIKE,
		"AC-18: 8-set tiebreak must return STRIKE (solo leader at prefix [0..5])")


## 3-way tie with previous_dominant_class == UNKNOWN → return UNKNOWN (NOT STRIKE, NOT alphabetical).
func test_ac18_three_way_tie_no_prior_leader_returns_unknown() -> void:
	# Construct an impossible 3-way tie from scratch (one each of STRIKE, CONTROL, MOBILITY)
	# Note: first-set is always unambiguous, so we need ≥2 sets for a tie.
	# Pattern: bench(S), row(C), squat(M), bench(S), row(C), squat(M) → S:2, C:2, M:2
	# But then tiebreak walk: at [0..1] S:1,C:1,M:0 → still tie between S and C...
	# For a "no prior solo leader" case: we need ALL prefixes to be ties.
	# That's actually hard with 3 classes. Instead test the sticky fallback:
	# After resetting _previous_dominant_class to UNKNOWN explicitly.
	WorkoutStateTracker.set(&"_previous_dominant_class", AbilitySystem.AbilityClass.UNKNOWN)
	WorkoutStateTracker.get(&"_set_history").clear()
	var history: Array = WorkoutStateTracker.get(&"_set_history")
	# 3 sets each — walk will find prefix with solo S leader at [0..0] (first set alone is solo)
	# To force case 4, we'd need first set to also be a tie — but 1 set can't tie.
	# So: use a 2-set equal tie that never had a solo leader in any prefix.
	# Pattern: bench(S), row(C) — at i=1: S:1,C:1 tie; at i=0: S:1 — STRIKE is solo leader.
	# This can't reach case 4 either. The GDD says "first-set scenario can never reach case 4".
	# So test sticky with _previous_dominant_class = UNKNOWN (never set) on an impossible case:
	# simulate by calling _resolve_tiebreak directly with no history.
	var leaders: Array = [
		AbilitySystem.AbilityClass.STRIKE,
		AbilitySystem.AbilityClass.CONTROL,
		AbilitySystem.AbilityClass.MOBILITY,
	]
	var result: int = WorkoutStateTracker.call("_resolve_tiebreak", leaders)
	# Empty set_history → no prefix can have solo leader → falls to sticky UNKNOWN
	assert_eq(result, AbilitySystem.AbilityClass.UNKNOWN,
		"AC-18: tiebreak with empty history and no prior leader must return UNKNOWN (not STRIKE)")


## Unambiguous single winner: no tiebreak needed.
func test_ac18_single_winner_returns_directly() -> void:
	WorkoutStateTracker.get(&"_set_history").clear()
	var history: Array = WorkoutStateTracker.get(&"_set_history")
	history.append({"exercise_id": &"bench_press", "reps": 8, "weight": 60.0})  # STRIKE
	history.append({"exercise_id": &"bench_press", "reps": 8, "weight": 60.0})  # STRIKE
	history.append({"exercise_id": &"row",         "reps": 8, "weight": 50.0})  # CONTROL

	var result: int = WorkoutStateTracker.call("_compute_dominant_class")
	assert_eq(result, AbilitySystem.AbilityClass.STRIKE,
		"Unambiguous STRIKE winner (2 vs 1 CONTROL) must return STRIKE directly")


# ---------------------------------------------------------------------------
# AC-10: dominant_class hysteresis cooldown (EC-21, injectable time-source)
# ---------------------------------------------------------------------------

## dominant_class_changed NOT emitted within cooldown window.
func test_ac10_class_change_suppressed_within_cooldown() -> void:
	# Establish CONTROL as current dominant class
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)     # CONTROL
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)     # CONTROL still dominant

	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.CONTROL,
		"Precondition: CONTROL must be dominant")

	# Inject T = 10s (within 30s cooldown)
	_fake_timer.now_ms = 10_000
	watch_signals(WorkoutStateTracker)

	# Add STRIKE sets to make STRIKE dominant — but within cooldown window
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)  # STRIKE:1
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)  # STRIKE:2
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)  # STRIKE:3 > CONTROL:2

	assert_signal_emit_count(WorkoutStateTracker, "dominant_class_changed", 0,
		"AC-10: dominant_class_changed must NOT emit within 30s cooldown window")
	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.CONTROL,
		"AC-10: cached class must stay CONTROL during cooldown")


## dominant_class_changed emitted after cooldown expires.
func test_ac10_class_change_allowed_after_cooldown() -> void:
	# Establish CONTROL as dominant (time=0, so last_change_ms=0)
	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)
	WorkoutStateTracker.call("_on_set_logged", &"row", 8, 50.0)

	# Advance time past 30s cooldown
	_fake_timer.now_ms = 31_000
	watch_signals(WorkoutStateTracker)

	# Now add STRIKE sets to flip
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	# STRIKE:3 > CONTROL:2; cooldown expired → flip allowed
	assert_signal_emit_count(WorkoutStateTracker, "dominant_class_changed", 1,
		"AC-10: dominant_class_changed must emit after 30s cooldown expires")
	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.STRIKE,
		"AC-10: cached class must flip to STRIKE after cooldown")


## First assignment (UNKNOWN → class) is immediate regardless of cooldown.
func test_ac10_first_assignment_immediate_no_cooldown() -> void:
	# Start workout — cached is UNKNOWN (no cooldown applies to first assignment)
	WorkoutStateTracker.call("_on_workout_started")
	_fake_timer.now_ms = 0  # time starts at 0
	watch_signals(WorkoutStateTracker)

	# First set_logged should immediately set class
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 8, 60.0)

	assert_signal_emit_count(WorkoutStateTracker, "dominant_class_changed", 1,
		"First class assignment must emit immediately (no cooldown for UNKNOWN → class)")
	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.STRIKE,
		"First set (bench_press) must immediately set STRIKE as dominant")


# ---------------------------------------------------------------------------
# AC-28: WST signal spy never emits STRIKE as a fallback (CI-3, #9 surface only)
# ---------------------------------------------------------------------------

## First set logged with unmapped exercise: no emit, no crash, cached stays UNKNOWN.
func test_first_unmapped_set_no_emit_no_crash() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	watch_signals(WorkoutStateTracker)

	WorkoutStateTracker.call("_on_set_logged", &"deadlift", 8, 100.0)

	assert_signal_emit_count(WorkoutStateTracker, "dominant_class_changed", 0,
		"First unmapped set must not emit dominant_class_changed (UNKNOWN→UNKNOWN early-return)")
	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.UNKNOWN,
		"First unmapped set must leave _cached_dominant_class as UNKNOWN")


## AC-28: _compute_dominant_class never returns STRIKE as a fallback for UNKNOWN exercises.
## Note: dominant_class_changed cannot emit UNKNOWN because _update_dominant_class early-returns
## when new_class == _cached (both UNKNOWN). AC-28's guarantee is proven at formula level.
func test_ac28_formula_never_returns_strike_for_unmapped_exercises() -> void:
	WorkoutStateTracker.call("_on_workout_started")
	watch_signals(WorkoutStateTracker)

	# Log 5 unmapped exercises (all UNKNOWN class)
	for i in range(5):
		WorkoutStateTracker.call("_on_set_logged", &"deadlift", 8, 100.0)

	# Formula-level proof: _compute_dominant_class returns UNKNOWN, not STRIKE (AC-28 CI-3)
	var formula_result: int = WorkoutStateTracker.call("_compute_dominant_class")
	assert_ne(formula_result, AbilitySystem.AbilityClass.STRIKE,
		"AC-28: _compute_dominant_class must NEVER return STRIKE for all-UNKNOWN exercises (CI-3)")
	assert_eq(formula_result, AbilitySystem.AbilityClass.UNKNOWN,
		"AC-28: _compute_dominant_class must return UNKNOWN when no mapped exercises")

	# Cached value confirms no fabrication
	assert_eq(WorkoutStateTracker.get(&"_cached_dominant_class"),
		AbilitySystem.AbilityClass.UNKNOWN,
		"AC-28: _cached_dominant_class must be UNKNOWN — never fabricated STRIKE")

	# Signal level: dominant_class_changed was NOT emitted (UNKNOWN→UNKNOWN early-return in _update)
	assert_signal_emit_count(WorkoutStateTracker, "dominant_class_changed", 0,
		"AC-28: dominant_class_changed must NOT emit for all-UNKNOWN workout (formula honest, not fabricated)")


## Tiebreak returning sticky previous class — still never fabricates STRIKE for UNKNOWN.
func test_ac28_tiebreak_sticky_previous_not_strike_fabrication() -> void:
	# Set up a prior known CONTROL dominance
	WorkoutStateTracker.set(&"_previous_dominant_class", AbilitySystem.AbilityClass.CONTROL)
	WorkoutStateTracker.call("_on_workout_started")
	# Construct a tie (STRIKE=1, CONTROL=1, MOBILITY=0 — tie between S and C)
	WorkoutStateTracker.get(&"_set_history").clear()
	WorkoutStateTracker.get(&"_set_history").append({"exercise_id": &"bench_press", "reps": 8, "weight": 60.0})
	WorkoutStateTracker.get(&"_set_history").append({"exercise_id": &"row", "reps": 8, "weight": 50.0})

	var result: int = WorkoutStateTracker.call("_compute_dominant_class")
	# Tiebreak walks: at i=0, prefix [0..0] = bench_press (STRIKE:1, CONTROL:0) → STRIKE solo leader
	# So result is STRIKE (from tiebreak walk), NOT fabrication — this is legitimate
	# The key: WST returns what the formula says, not a forced STRIKE default
	assert_ne(result, AbilitySystem.AbilityClass.UNKNOWN,
		"With one set each of STRIKE and CONTROL, tiebreak should find solo leader at prefix [0..0]")
	# Verify the formula, not a default zero-value
	assert_eq(result, AbilitySystem.AbilityClass.STRIKE,
		"Tiebreak with prefix [0..0]=STRIKE solo → STRIKE from algorithm (not zero-default fabrication)")
