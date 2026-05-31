# AbilitySystem — Story 005 AC-09: connect_for_initial_state wrapper
#
# Coverage:
#   AC-09 — AbilitySystem.connect_for_initial_state(callable) thin wrapper:
#     - callable is connected to ability_cast after the call
#     - emitting ability_cast fires the callable
#     - NO initial-state sentinel replay (unlike GSM's Contract 6 sentinel)
#
# This verifies that the wrapper added in Story 005 satisfies CI lint
# (check_enemy_director_signal_subscription.gd enforces no raw .ability_cast.connect()).
extends GutTest


## Simple recorder to verify the callable was invoked with correct args.
class CastRecorder:
	var call_count: int = 0
	var last_ability_id: StringName = &""

	func on_cast(ability_id: StringName, _caster: Node2D, _target: Node2D) -> void:
		call_count += 1
		last_ability_id = ability_id


var _recorder: CastRecorder


func before_each() -> void:
	await get_tree().process_frame
	_recorder = CastRecorder.new()


func after_each() -> void:
	await get_tree().process_frame
	# Disconnect to avoid leaking across tests.
	if AbilitySystem.ability_cast.is_connected(_recorder.on_cast):
		AbilitySystem.ability_cast.disconnect(_recorder.on_cast)


# ---------------------------------------------------------------------------
# AC-09: connect_for_initial_state connects callable to ability_cast
# ---------------------------------------------------------------------------

## connect_for_initial_state must connect the callable so it fires on emission.
func test_ac09_connect_for_initial_state_wires_callable() -> void:
	# Arrange
	assert_false(
		AbilitySystem.ability_cast.is_connected(_recorder.on_cast),
		"Precondition: callable must not be connected before the call"
	)
	# Act
	AbilitySystem.connect_for_initial_state(_recorder.on_cast)
	# Assert
	assert_true(
		AbilitySystem.ability_cast.is_connected(_recorder.on_cast),
		"AC-09: connect_for_initial_state must wire callable to ability_cast"
	)


## Emitting ability_cast after connect must invoke the registered callable.
func test_ac09_callable_fires_on_ability_cast_emit() -> void:
	# Arrange
	AbilitySystem.connect_for_initial_state(_recorder.on_cast)
	assert_eq(_recorder.call_count, 0, "Precondition: recorder must not have fired yet")
	# Act — emit via signal (no live cast needed; directly emit the signal for test isolation)
	AbilitySystem.ability_cast.emit(&"ABILITY_STRIKE_1", null, null)
	# Assert
	assert_eq(_recorder.call_count, 1, "AC-09: callable must fire once on ability_cast emit")
	assert_eq(_recorder.last_ability_id, &"ABILITY_STRIKE_1",
		"AC-09: callable must receive the emitted ability_id")


## connect_for_initial_state must NOT perform initial-state sentinel replay.
## (Unlike GameStateMachine.connect_for_initial_state which defers a callv of the
## current state. ability_cast is an event signal with no persistent current state.)
func test_ac09_no_initial_state_sentinel_replay() -> void:
	# Arrange — recorder count must stay 0 immediately after connect (no deferred replay).
	AbilitySystem.connect_for_initial_state(_recorder.on_cast)
	# Act — process one frame to let any deferred calls fire
	await get_tree().process_frame
	# Assert — should still be 0 (no replay, only real casts trigger the callable)
	assert_eq(_recorder.call_count, 0,
		"AC-09: connect_for_initial_state must NOT fire an initial-state replay for ability_cast")
