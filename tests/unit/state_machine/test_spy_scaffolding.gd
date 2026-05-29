# GameStateMachine — Story 007 AC-18a/spy-1/spy-2 Test Spy Scaffolding
#
# Scope: verifies the GSM test spy interface (Contract 14) and the
# StateMachineSpies helper module.
#
# AC-18a covered by CI script (`check_no_await_in_state_machine.sh`) — this
# test file proves the spy interface exists; the CI script proves no-await.
# AC-gsm-spy-1: GSM in-memory spy fires on state mutations
# AC-gsm-spy-2: StateMachineSpies helper exposes all expected attachment methods
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 12 (no-await) + Contract 14 (spy interface)
extends GutTest


func before_each() -> void:
	GameStateMachine.clear_spies()


func after_each() -> void:
	GameStateMachine.clear_spies()


## AC-gsm-spy-1: attach_in_memory_spy + manual notify → callback fires.
func test_gsm_in_memory_spy_fires_on_notify() -> void:
	# Arrange
	var log: Array = []
	GameStateMachine.attach_in_memory_spy(
		func(old_state: int, new_state: int) -> void:
			log.append({"old": old_state, "new": new_state})
	)

	# Act — directly invoke the notify helper (Story 002 will wire transitions)
	GameStateMachine._notify_in_memory_spies(
		GameStateMachine.GameState.BOOTING,
		GameStateMachine.GameState.IDLE
	)

	# Assert
	assert_eq(log.size(), 1, "Spy must fire once per notify call")
	assert_eq(log[0]["old"], GameStateMachine.GameState.BOOTING)
	assert_eq(log[0]["new"], GameStateMachine.GameState.IDLE)


## AC-gsm-spy-1 isolation: clear_spies() drops all attached callbacks.
func test_gsm_clear_spies_drops_attached_callbacks() -> void:
	# Arrange
	var log: Array = []
	GameStateMachine.attach_in_memory_spy(
		func(_o: int, _n: int) -> void: log.append("fired")
	)

	# Act
	GameStateMachine.clear_spies()
	GameStateMachine._notify_in_memory_spies(
		GameStateMachine.GameState.IDLE,
		GameStateMachine.GameState.WORKOUT_ACTIVE
	)

	# Assert
	assert_eq(log.size(), 0, "clear_spies() must drop all callbacks")


## AC-gsm-spy-2: StateMachineSpies helper exposes attach_all / detach_all.
func test_state_machine_spies_helper_attach_detach_cycle() -> void:
	# Arrange
	var spies := StateMachineSpies.new()

	# Act
	spies.attach_all()
	GameStateMachine._notify_in_memory_spies(
		GameStateMachine.GameState.BOOTING,
		GameStateMachine.GameState.IDLE
	)

	# Assert — in_memory_log captured the mutation
	assert_eq(spies.in_memory_log.size(), 1, "Helper must capture GSM mutation")
	assert_eq(spies.in_memory_log[0]["old"], GameStateMachine.GameState.BOOTING)

	# Cleanup
	spies.detach_all()
	assert_eq(spies.in_memory_log.size(), 0, "detach_all() must clear logs")


## Additional: multiple spies can attach independently.
func test_gsm_multiple_spies_all_fire() -> void:
	# Arrange
	var log_a: Array = []
	var log_b: Array = []
	GameStateMachine.attach_in_memory_spy(func(_o, _n) -> void: log_a.append("a"))
	GameStateMachine.attach_in_memory_spy(func(_o, _n) -> void: log_b.append("b"))

	# Act
	GameStateMachine._notify_in_memory_spies(
		GameStateMachine.GameState.IDLE,
		GameStateMachine.GameState.WORKOUT_ACTIVE
	)

	# Assert
	assert_eq(log_a.size(), 1, "Spy A must fire")
	assert_eq(log_b.size(), 1, "Spy B must fire")
