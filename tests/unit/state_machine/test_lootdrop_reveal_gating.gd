# GameStateMachine — Story 014 Rule 13 LootDrop Reveal Gating
extends GutTest


func before_each() -> void:
	PersistenceLayer.get(&"_cache").erase("gsm.loot_reveal_pending")


## AC-13-1: pending + IDLE → reveal triggered (true)
func test_loot_reveal_in_idle_returns_true() -> void:
	PersistenceLayer.write("gsm.loot_reveal_pending", true)
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.IDLE)

	assert_true(GameStateMachine._check_pending_loot_reveal(),
		"AC-13-1: pending+IDLE must allow reveal")


## AC-13-2: pending + WORKOUT_ACTIVE → suppressed (false)
func test_loot_reveal_in_workout_active_suppressed() -> void:
	PersistenceLayer.write("gsm.loot_reveal_pending", true)
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.WORKOUT_ACTIVE)

	assert_false(GameStateMachine._check_pending_loot_reveal(),
		"AC-13-2: WORKOUT_ACTIVE must suppress reveal")


## AC-13-3: pending + DISCONNECTED → reveal triggered
func test_loot_reveal_in_disconnected_returns_true() -> void:
	PersistenceLayer.write("gsm.loot_reveal_pending", true)
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.DISCONNECTED)

	assert_true(GameStateMachine._check_pending_loot_reveal(),
		"AC-13-3: DISCONNECTED is safe — reveal allowed")


## Additional: no pending → false regardless of state
func test_loot_reveal_no_pending_returns_false() -> void:
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.IDLE)

	assert_false(GameStateMachine._check_pending_loot_reveal(),
		"No pending flag → no reveal")
