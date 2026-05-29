# GameStateMachine — Story 011 Boot Reconciliation Rule 5
#
# Scope: priority cascade for boot state resolution.
# AC-gsm-r5-1: no stored state → IDLE (priority 5 default)
# AC-gsm-r5-2: stored state → resume (priority 2 explicit)
# AC-gsm-r5-3: tombstone → forward-recovery (priority 1)
#
# Framework: GUT (Godot Unit Testing) v7.x
extends GutTest


func before_each() -> void:
	# Clear all keys Rule 5 reads
	PersistenceLayer.get(&"_cache").erase("gsm.current_state")
	PersistenceLayer.get(&"_cache").erase("gsm.pending_transition")
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.BOOTING)


## AC-gsm-r5-1: no stored state + no tombstone → IDLE default.
func test_rule5_no_stored_state_returns_idle_default() -> void:
	# Act
	GameStateMachine._run_rule5_reconciliation()

	# Assert
	assert_eq(
		GameStateMachine.get_current_state(),
		GameStateMachine.GameState.IDLE,
		"AC-gsm-r5-1: no stored state must default to IDLE"
	)


## AC-gsm-r5-2: stored state explicitly → resume that state.
func test_rule5_stored_state_resumed() -> void:
	# Arrange — store DISCONNECTED explicitly
	PersistenceLayer.write("gsm.current_state", "DISCONNECTED")

	# Act
	GameStateMachine._run_rule5_reconciliation()

	# Assert
	assert_eq(
		GameStateMachine.get_current_state(),
		GameStateMachine.GameState.DISCONNECTED,
		"AC-gsm-r5-2: explicit stored state must be resumed"
	)


## AC-gsm-r5-3: tombstone present → forward-recovery.
func test_rule5_tombstone_triggers_forward_recovery() -> void:
	# Arrange — craft tombstone targeting WORKOUT_ACTIVE
	var tombstone: Dictionary = {
		"transition_id": "rule5_test_tid",
		"from": "BOOTING",
		"to": "WORKOUT_ACTIVE",
		"wall_clock_anchor": int(Time.get_unix_time_from_system()),
		"monotonic_anchor": Time.get_ticks_usec(),
		"payload": {},
		"payload_type": "",
	}
	PersistenceLayer.write("gsm.pending_transition", tombstone, true)

	# Act
	GameStateMachine._run_rule5_reconciliation()

	# Assert
	assert_eq(
		GameStateMachine.get_current_state(),
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		"AC-gsm-r5-3: tombstone forward-recovery must apply target state"
	)
	# Tombstone removed after recovery
	assert_null(PersistenceLayer.read("gsm.pending_transition"),
		"Tombstone must be removed after forward-recovery")


## AC-26: Rule 5 runs synchronously (no await in path).
func test_rule5_runs_synchronously() -> void:
	# Act — _run_rule5_reconciliation should not require await
	var completed: bool = false
	GameStateMachine._run_rule5_reconciliation()
	completed = true
	assert_true(completed, "Rule 5 must return synchronously (no await)")
