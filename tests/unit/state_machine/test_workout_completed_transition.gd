# GameStateMachine — Story 013 Rule 7 workout_completed Tests
extends GutTest


func before_each() -> void:
	GameStateMachine.set(&"_event_queue", [])
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.WORKOUT_ACTIVE)


## AC-gsm-wc-1: workout_completed from WORKOUT_ACTIVE → enqueues LOOT_DROP
func test_workout_completed_from_workout_active_enqueues_loot_drop() -> void:
	# Act
	GameStateMachine.on_workout_completed("wk_123")

	# Assert — event enqueued at priority 1, target LOOT_DROP
	var queue: Array = GameStateMachine.get(&"_event_queue")
	assert_eq(queue.size(), 1, "Exactly 1 event enqueued")
	assert_eq(queue[0]["target_state"], GameStateMachine.GameState.LOOT_DROP)
	assert_eq(queue[0]["priority"], 1, "Priority 1 = force-transition")


## AC-gsm-wc-2: from BOSS_ENCOUNTER → payload contains INTERRUPTED_WITH_CREDIT
func test_workout_completed_from_boss_encounter_includes_interrupted_credit() -> void:
	# Arrange
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.BOSS_ENCOUNTER)

	# Act
	GameStateMachine.on_workout_completed("wk_456")

	# Assert
	var queue: Array = GameStateMachine.get(&"_event_queue")
	var payload: StateTransitionPayload = queue[0]["event"]
	assert_true(payload.data.has("boss"), "Boss payload must be attached")
	var boss_dict: Dictionary = payload.data["boss"]
	assert_eq(boss_dict.get("outcome"), "INTERRUPTED_WITH_CREDIT",
		"Boss outcome must be INTERRUPTED_WITH_CREDIT mid-encounter")


## AC-gsm-wc-3: priority 1 drained before priority 2.
func test_workout_completed_priority_1_drains_before_priority_2() -> void:
	# Arrange — enqueue normal event first, then workout_completed
	GameStateMachine.enqueue_event("normal_event", GameStateMachine.GameState.IDLE, 2)
	GameStateMachine.on_workout_completed("wk_789")

	# Assert — workout (priority 1) at front
	var queue: Array = GameStateMachine.get(&"_event_queue")
	assert_eq(queue[0]["priority"], 1, "Priority 1 (workout) must be first")
	assert_eq(queue[1]["priority"], 2, "Priority 2 (normal) must be second")
