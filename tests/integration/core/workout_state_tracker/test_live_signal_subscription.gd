# WorkoutStateTracker — Story 012 Live #2 Signal Subscription (AC-01)
#
# Coverage:
#   AC-01 — TR-wst-001: WST subscribes to EXACTLY 7 #2 GymSysBackendClient signals.
#     - 5 core workout events: workout_started / set_logged / rest_started /
#       rest_ended / workout_completed (ADR-0002 Locked contract)
#     - 2 connection-health events: poll_failed / poll_recovered (#2 GDD Rule 12)
#     - Each signal connected to the matching _on_* handler via Signal.is_connected()
#     - null _gym_sys_client → _connect_gym_sys_signals() is a graceful no-op
#
# Mock-scoped: GymSysBackendClient autoload does not exist yet. FakeGymSysClient
# declares the 7 Locked signals; the WST source never references the global name.
extends GutTest


## Fake #2 GymSysBackendClient — declares exactly the 7 Locked ADR-0002 signals.
## Extends Object (not Node) — DI seam is untyped so a RefCounted/Object double works.
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


## Minimal #11 StatSystem spy — READY substate, no-op apply_stat_delta.
class FakeStatSystemSpy:
	func get_substate() -> int: return 1  # Substate.READY ordinal
	func apply_stat_delta(_stat_id: StringName, _source: int, _delta: float) -> void:
		pass


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
	# Tear down the wiring, then restore DI seams to real autoloads.
	WorkoutStateTracker.call("_disconnect_gym_sys_signals")
	WorkoutStateTracker.set(&"_gym_sys_client", null)
	WorkoutStateTracker.set(&"_persistence_layer", PersistenceLayer)
	WorkoutStateTracker.set(&"_stat_system", StatSystem)


# ---------------------------------------------------------------------------
# AC-01: each of the 7 signals must be connected to the matching _on_* handler
# ---------------------------------------------------------------------------

func test_ac01_workout_started_signal_is_connected() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert
	assert_true(
		_fake_gym_client.workout_started.is_connected(Callable(WorkoutStateTracker, "_on_workout_started")),
		"AC-01: workout_started must be connected to _on_workout_started"
	)


func test_ac01_set_logged_signal_is_connected() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert
	assert_true(
		_fake_gym_client.set_logged.is_connected(Callable(WorkoutStateTracker, "_on_set_logged")),
		"AC-01: set_logged must be connected to _on_set_logged"
	)


func test_ac01_rest_started_signal_is_connected() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert
	assert_true(
		_fake_gym_client.rest_started.is_connected(Callable(WorkoutStateTracker, "_on_rest_started")),
		"AC-01: rest_started must be connected to _on_rest_started"
	)


func test_ac01_rest_ended_signal_is_connected() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert
	assert_true(
		_fake_gym_client.rest_ended.is_connected(Callable(WorkoutStateTracker, "_on_rest_ended")),
		"AC-01: rest_ended must be connected to _on_rest_ended"
	)


func test_ac01_workout_completed_signal_is_connected() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert
	assert_true(
		_fake_gym_client.workout_completed.is_connected(Callable(WorkoutStateTracker, "_on_workout_completed")),
		"AC-01: workout_completed must be connected to _on_workout_completed"
	)


func test_ac01_poll_failed_signal_is_connected() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert
	assert_true(
		_fake_gym_client.poll_failed.is_connected(Callable(WorkoutStateTracker, "_on_poll_failed")),
		"AC-01: poll_failed must be connected to _on_poll_failed"
	)


func test_ac01_poll_recovered_signal_is_connected() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert
	assert_true(
		_fake_gym_client.poll_recovered.is_connected(Callable(WorkoutStateTracker, "_on_poll_recovered")),
		"AC-01: poll_recovered must be connected to _on_poll_recovered"
	)


## All 7 connections verified in a single boolean assertion (TR-wst-001 exact set).
func test_ac01_all_7_connections_in_one_assertion_pass() -> void:
	# Arrange / Act — wiring done in before_each.
	# Assert — every one of the 7 Locked signals is wired.
	var all_connected: bool = (
		_fake_gym_client.workout_started.is_connected(Callable(WorkoutStateTracker, "_on_workout_started"))
		and _fake_gym_client.set_logged.is_connected(Callable(WorkoutStateTracker, "_on_set_logged"))
		and _fake_gym_client.rest_started.is_connected(Callable(WorkoutStateTracker, "_on_rest_started"))
		and _fake_gym_client.rest_ended.is_connected(Callable(WorkoutStateTracker, "_on_rest_ended"))
		and _fake_gym_client.workout_completed.is_connected(Callable(WorkoutStateTracker, "_on_workout_completed"))
		and _fake_gym_client.poll_failed.is_connected(Callable(WorkoutStateTracker, "_on_poll_failed"))
		and _fake_gym_client.poll_recovered.is_connected(Callable(WorkoutStateTracker, "_on_poll_recovered"))
	)
	assert_true(all_connected,
		"AC-01: all 7 #2 GymSysBackendClient signals must be connected (TR-wst-001 exact set)")


## Null client → _connect_gym_sys_signals() is a graceful no-op (no crash);
## re-injecting a real client then wires up so an emitted signal drives WST.
## Behaviour-based (emit) rather than is_connected() to verify the end-to-end
## wiring effect, which is what the production path actually relies on.
func test_ac01_null_client_connect_is_graceful_noop() -> void:
	# Arrange — tear down the before_each wiring; set the client to null.
	WorkoutStateTracker.call("_disconnect_gym_sys_signals")
	WorkoutStateTracker.set(&"_gym_sys_client", null)

	# Act 1 — connecting with a null client must not crash. Reaching the next
	# line (and the assert) proves the graceful no-op path executed.
	WorkoutStateTracker.call("_connect_gym_sys_signals")

	# Assert 1 — with no client wired, WST is untouched and stays IDLE.
	assert_eq(WorkoutStateTracker.get_current_phase(), WorkoutStateTracker.WorkoutPhase.IDLE,
		"AC-01: null client connect is a no-op — WST stays IDLE")

	# Act 2 — inject a fresh client, wire it, and emit workout_started.
	var fresh_client := FakeGymSysClient.new()
	WorkoutStateTracker.set(&"_gym_sys_client", fresh_client)
	WorkoutStateTracker.call("_connect_gym_sys_signals")
	fresh_client.workout_started.emit()

	# Assert 2 — the wiring is live: the emitted signal drove WST into WARM_UP.
	assert_eq(WorkoutStateTracker.get_current_phase(), WorkoutStateTracker.WorkoutPhase.WARM_UP,
		"AC-01: after re-injecting a client + connect, emitted workout_started drives WARM_UP")
