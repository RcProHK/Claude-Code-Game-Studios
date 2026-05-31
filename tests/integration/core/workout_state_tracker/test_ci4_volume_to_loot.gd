# WorkoutStateTracker — Story 010 Volume-to-Loot CI-4 Integration Test
#
# Coverage:
#   AC-29 — CI-4: WorkoutSummaryRO → #15 LootDrop volume_factor wiring
#     - workout_summary_available emits with populated fields
#     - mock #15 spy reads completed_exercises_count + total_volume
#     - volume_factor = min(1.0, count/5) computed correctly (ADR-005)
#     - transition_id is present and non-empty
#     - Edge: count < 5 → volume_factor < 1.0; count > 5 → volume_factor capped at 1.0
extends GutTest


## FakePersistenceLayer from Story 008 pattern (minimal — supports read/write/is_expired).
class FakePersistenceLayer:
	var data: Dictionary = {}
	func read(key: String) -> Variant: return data.get(key, null)
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool: return true
	func is_expired(_anchor: int, _ttl: int, _mono: int = 0) -> bool: return false
	func has_method(m: String) -> bool: return m in ["read", "write", "is_expired"]


## Mock #15 LootDrop subscriber — connects to workout_summary_available and records fields.
class FakeLootDropSpy:
	var received_summary: WorkoutSummaryRO = null

	func on_workout_summary_available(summary: WorkoutSummaryRO) -> void:
		received_summary = summary


var _fake_pl: FakePersistenceLayer
var _loot_spy: FakeLootDropSpy


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
	WorkoutStateTracker.get(&"_completed_exercises").clear()
	WorkoutStateTracker.set(&"_last_snapshot", null)
	WorkoutStateTracker.set(&"_last_summary", null)
	WorkoutStateTracker.set(&"_last_workout_transition_id", "")
	WorkoutStateTracker.get(&"_pending_stat_deltas").clear()
	WorkoutStateTracker.set(&"_stat_delta_overflow_count", 0)
	WorkoutStateTracker.set(&"_workout_started_at_s", 0)
	# Inject fake PersistenceLayer
	_fake_pl = FakePersistenceLayer.new()
	WorkoutStateTracker.set(&"_persistence_layer", _fake_pl)
	# Create fresh spy
	_loot_spy = FakeLootDropSpy.new()


func after_each() -> void:
	await get_tree().process_frame
	# Each test explicitly disconnects its own signal connections before returning.
	# Restore injected DI seams to real autoloads.
	WorkoutStateTracker.set(&"_persistence_layer", PersistenceLayer)
	WorkoutStateTracker.set(&"_stat_system", StatSystem)


# ---------------------------------------------------------------------------
# AC-29: CI-4 — WorkoutSummaryRO → volume_factor wiring (main case)
# ---------------------------------------------------------------------------

## workout_completed with 5 distinct exercises (100kg×2reps each) yields
## total_volume=1000.0 and volume_factor=1.0 (5/5 capped).
func test_ac29_five_distinct_exercises_gives_volume_factor_1_0() -> void:
	# Connect spy to workout_summary_available BEFORE workout starts
	WorkoutStateTracker.workout_summary_available.connect(_loot_spy.on_workout_summary_available)

	WorkoutStateTracker.call("_on_workout_started")
	# 5 distinct exercises × 2 reps × 100kg = 200 per set × 5 = total_volume=1000
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 2, 100.0)   # E1
	WorkoutStateTracker.call("_on_set_logged", &"row", 2, 100.0)            # E2
	WorkoutStateTracker.call("_on_set_logged", &"squat", 2, 100.0)          # E3
	WorkoutStateTracker.call("_on_set_logged", &"deadlift", 2, 100.0)       # E4
	WorkoutStateTracker.call("_on_set_logged", &"overhead_press", 2, 100.0) # E5

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	# Spy must have received the summary
	assert_not_null(_loot_spy.received_summary,
		"AC-29: mock #15 spy must receive WorkoutSummaryRO via workout_summary_available")

	var summary: WorkoutSummaryRO = _loot_spy.received_summary

	# Verify completed_exercises_count == 5 (distinct count)
	assert_eq(summary.completed_exercises_count, 5,
		"AC-29: WorkoutSummaryRO.completed_exercises_count must be 5 (5 distinct exercises)")

	# Verify total_volume == 1000.0 (Formula 4: Σ reps×weight = 5 × 2 × 100)
	assert_almost_eq(summary.total_volume, 1000.0, 0.01,
		"AC-29: WorkoutSummaryRO.total_volume must be 1000.0")

	# Verify transition_id is non-empty (ADR-005 RNG seeding)
	assert_ne(summary.transition_id, "",
		"AC-29: WorkoutSummaryRO.transition_id must be non-empty for #15 RNG seeding")

	# Compute volume_factor per ADR-005 formula (this is what #15 would do)
	var exercise_target_count: int = 5  # ADR-005 registry-locked
	var volume_factor: float = minf(1.0, float(summary.completed_exercises_count) / float(exercise_target_count))
	assert_almost_eq(volume_factor, 1.0, 0.001,
		"AC-29: ADR-005 volume_factor = min(1.0, 5/5) must be 1.0")

	WorkoutStateTracker.workout_summary_available.disconnect(_loot_spy.on_workout_summary_available)


## Edge: completed_exercises_count < 5 → volume_factor < 1.0
func test_ac29_edge_three_exercises_gives_volume_factor_0_6() -> void:
	WorkoutStateTracker.workout_summary_available.connect(_loot_spy.on_workout_summary_available)

	WorkoutStateTracker.call("_on_workout_started")
	# 3 distinct exercises
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)
	WorkoutStateTracker.call("_on_set_logged", &"row", 5, 50.0)
	WorkoutStateTracker.call("_on_set_logged", &"squat", 5, 80.0)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	assert_not_null(_loot_spy.received_summary, "Spy must receive summary")
	var volume_factor: float = minf(1.0, float(_loot_spy.received_summary.completed_exercises_count) / 5.0)
	assert_almost_eq(volume_factor, 0.6, 0.001,
		"AC-29 edge: 3/5 exercises → volume_factor = 0.6")
	assert_eq(_loot_spy.received_summary.completed_exercises_count, 3,
		"AC-29 edge: completed_exercises_count must be 3")

	WorkoutStateTracker.workout_summary_available.disconnect(_loot_spy.on_workout_summary_available)


## Edge: completed_exercises_count > 5 → volume_factor capped at 1.0
func test_ac29_edge_seven_exercises_volume_factor_capped_at_1_0() -> void:
	WorkoutStateTracker.workout_summary_available.connect(_loot_spy.on_workout_summary_available)

	WorkoutStateTracker.call("_on_workout_started")
	# 7 distinct exercises
	var exercises: Array[StringName] = [
		&"bench_press", &"row", &"squat", &"deadlift",
		&"overhead_press", &"bicep_curl", &"tricep_pushdown"
	]
	for ex: StringName in exercises:
		WorkoutStateTracker.call("_on_set_logged", ex, 5, 60.0)

	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	assert_not_null(_loot_spy.received_summary, "Spy must receive summary")
	assert_eq(_loot_spy.received_summary.completed_exercises_count, 7,
		"AC-29 edge: completed_exercises_count must be 7")
	var volume_factor: float = minf(1.0, float(_loot_spy.received_summary.completed_exercises_count) / 5.0)
	assert_almost_eq(volume_factor, 1.0, 0.001,
		"AC-29 edge: 7/5 → min(1.0, 1.4) = 1.0 (capped)")

	WorkoutStateTracker.workout_summary_available.disconnect(_loot_spy.on_workout_summary_available)


## Confirm emission order: workout_summary_available fires BEFORE workout_completed_forwarded.
func test_ac29_emission_order_summary_before_forwarded() -> void:
	var order: Array[String] = []
	WorkoutStateTracker.workout_summary_available.connect(
		func(_s: WorkoutSummaryRO) -> void: order.append("summary_available"),
		CONNECT_ONE_SHOT
	)
	WorkoutStateTracker.workout_completed_forwarded.connect(
		func(_t: int, _id: String) -> void: order.append("completed_forwarded"),
		CONNECT_ONE_SHOT
	)

	WorkoutStateTracker.call("_on_workout_started")
	WorkoutStateTracker.call("_on_set_logged", &"bench_press", 5, 60.0)
	WorkoutStateTracker.call("_on_workout_completed", 1748284800)

	assert_eq(order.size(), 2,
		"AC-29 ordering: both signals must have fired")
	assert_eq(order[0], "summary_available",
		"AC-29 ordering: workout_summary_available must fire BEFORE workout_completed_forwarded (Rule 10)")
	assert_eq(order[1], "completed_forwarded",
		"AC-29 ordering: workout_completed_forwarded fires second")
