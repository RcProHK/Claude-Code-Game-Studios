# WorkoutStateTracker — Story 012 Anti-Fabrication Chain (AC-42)
#
# Coverage:
#   AC-42 — Pillar 1 anti-fabrication: events arriving WITHOUT a preceding
#     workout_started must produce ZERO downstream effects.
#     - set_logged in IDLE → dropped (EC-02), phase stays IDLE, set_progress 0,
#       no Stat.apply_stat_delta
#     - workout_completed in IDLE → dropped (EC-01), no workout_summary_available,
#       no workout_completed_forwarded, phase stays IDLE
#     - Full chain (skip workout_started entirely) → zero rewards
#
# Drives the live #2 wiring: events are emitted via FakeGymSysClient so the test
# also exercises the Story 012 signal subscription path end-to-end.
extends GutTest


## Fake #2 GymSysBackendClient — 7 Locked ADR-0002 signals.
class FakeGymSysClient:
	signal workout_started()
	signal set_logged(exercise_id: StringName, reps: int, weight: float)
	signal rest_started(duration_seconds: int)
	signal rest_ended()
	signal workout_completed(completed_at: int)
	signal poll_failed(category: StringName)
	signal poll_recovered()


## FakePersistenceLayer from Story 008 pattern (minimal — read/write/is_expired).
class FakePersistenceLayer:
	var data: Dictionary = {}
	func read(key: String) -> Variant: return data.get(key, null)
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool: return true
	func is_expired(_anchor: int, _ttl: int, _mono: int = 0) -> bool: return false


## #11 StatSystem spy — counts apply_stat_delta invocations. READY substate.
## Does NOT override has_signal/has_method — Godot 4.6 treats overriding a native
## Object method as a warning-as-error (parse fail). The built-in has_method()
## auto-detects the methods declared in this class body, which is all WST queries.
## In every AC-42 case WST early-returns (EC-01/EC-02) before reaching the stat
## routing path, so the spy is never queried — apply_delta_count must stay 0.
class FakeStatSystemSpy:
	var apply_delta_count: int = 0
	func get_substate() -> int: return 1  # Substate.READY ordinal
	func apply_stat_delta(_stat_id: StringName, _source: int, _delta: float) -> void:
		apply_delta_count += 1


var _fake_pl: FakePersistenceLayer
var _fake_gym_client: FakeGymSysClient
var _stat_spy: FakeStatSystemSpy


func before_each() -> void:
	await get_tree().process_frame
	# Reset full WST state (Story 010 before_each pattern).
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
	# Inject fake PersistenceLayer + StatSystem spy.
	_fake_pl = FakePersistenceLayer.new()
	WorkoutStateTracker.set(&"_persistence_layer", _fake_pl)
	_stat_spy = FakeStatSystemSpy.new()
	WorkoutStateTracker.set(&"_stat_system", _stat_spy)
	# Inject fake #2 GymSysBackendClient and wire the 7 signals.
	_fake_gym_client = FakeGymSysClient.new()
	WorkoutStateTracker.set(&"_gym_sys_client", _fake_gym_client)
	WorkoutStateTracker.call("_connect_gym_sys_signals")


func after_each() -> void:
	await get_tree().process_frame
	WorkoutStateTracker.call("_disconnect_gym_sys_signals")
	WorkoutStateTracker.set(&"_gym_sys_client", null)
	WorkoutStateTracker.set(&"_persistence_layer", PersistenceLayer)
	WorkoutStateTracker.set(&"_stat_system", StatSystem)


# ---------------------------------------------------------------------------
# AC-42: anti-fabrication — no workout_started means no downstream effects
# ---------------------------------------------------------------------------

## set_logged with no preceding workout_started (EC-02) is dropped: phase stays
## IDLE, set_progress stays 0, no stat delta applied.
func test_ac42_set_logged_without_workout_started_drops_and_stays_idle() -> void:
	# Arrange
	watch_signals(WorkoutStateTracker)

	# Act — emit set_logged via the live #2 wiring with no workout_started first.
	_fake_gym_client.set_logged.emit(&"squat", 3, 80.0)

	# Assert
	assert_eq(WorkoutStateTracker.get_current_phase(), WorkoutStateTracker.WorkoutPhase.IDLE,
		"AC-42: phase stays IDLE after fabricated set_logged")
	assert_almost_eq(WorkoutStateTracker.get_set_progress(), 0.0, 0.001,
		"AC-42: set_progress stays 0 (no set recorded)")
	assert_eq(_stat_spy.apply_delta_count, 0,
		"AC-42: Stat.apply_stat_delta never invoked for a dropped set")


## workout_completed with no active workout (EC-01) is dropped: no summary,
## no forwarded signal, phase stays IDLE.
func test_ac42_workout_completed_without_workout_started_drops_and_no_summary() -> void:
	# Arrange
	watch_signals(WorkoutStateTracker)

	# Act — emit workout_completed via live wiring with no active workout.
	_fake_gym_client.workout_completed.emit(1748284800)
	await get_tree().process_frame

	# Assert
	assert_signal_not_emitted(WorkoutStateTracker, "workout_summary_available",
		"AC-42: no workout_summary_available without workout_started")
	assert_signal_not_emitted(WorkoutStateTracker, "workout_completed_forwarded",
		"AC-42: no workout_completed_forwarded without workout_started")
	assert_eq(WorkoutStateTracker.get_current_phase(), WorkoutStateTracker.WorkoutPhase.IDLE,
		"AC-42: phase stays IDLE after fabricated workout_completed")


## No stat delta is routed when set_logged arrives without workout_started.
func test_ac42_no_stat_delta_without_workout_started() -> void:
	# Arrange — spy starts at 0.

	# Act
	_fake_gym_client.set_logged.emit(&"bench_press", 5, 60.0)

	# Assert
	assert_eq(_stat_spy.apply_delta_count, 0,
		"AC-42: no Stat.apply_stat_delta without a preceding workout_started")


## Full chain: skip workout_started, send set_logged + workout_completed → zero rewards.
func test_ac42_full_chain_skip_workout_started_zero_rewards() -> void:
	# Arrange
	watch_signals(WorkoutStateTracker)

	# Act — fabricated event sequence with no workout_started.
	_fake_gym_client.set_logged.emit(&"bench_press", 5, 60.0)
	_fake_gym_client.workout_completed.emit(1748284800)
	await get_tree().process_frame

	# Assert — nothing was recorded, computed, applied, or forwarded.
	assert_almost_eq(WorkoutStateTracker.get_set_progress(), 0.0, 0.001,
		"AC-42: set_progress stays 0")
	assert_eq(_stat_spy.apply_delta_count, 0,
		"AC-42: Stat.apply_stat_delta never invoked")
	assert_signal_not_emitted(WorkoutStateTracker, "workout_summary_available",
		"AC-42: no summary without workout_started")
	assert_signal_not_emitted(WorkoutStateTracker, "workout_completed_forwarded",
		"AC-42: no forwarded without workout_started")
	assert_eq(WorkoutStateTracker.get_current_phase(), WorkoutStateTracker.WorkoutPhase.IDLE,
		"AC-42: phase stays IDLE")
