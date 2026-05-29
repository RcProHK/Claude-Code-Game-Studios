# GameStateMachine — Story 009 Event Intake Queue Tests
#
# Scope: ADR-0006 Contract 1 Event Intake Queue — priority FIFO + 1-per-frame
# drain + validity re-check.
#
# AC-gsm-queue-1: priority order respected (0 drained before 1 before 2)
# AC-gsm-queue-2: validity re-check skips stale events
# AC-gsm-queue-3: 1 event per frame drained (not all)
#
# Framework: GUT (Godot Unit Testing) v7.x
extends GutTest


const QUEUE_VAR: StringName = &"_event_queue"


func before_each() -> void:
	GameStateMachine.set(QUEUE_VAR, [])
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.BOOTING)
	GameStateMachine.set(&"_transitioning", false)


## AC-gsm-queue-1: events processed in priority order.
func test_event_queue_priority_order_respected() -> void:
	# Arrange — enqueue 3 events at priorities [2, 0, 1]
	GameStateMachine.enqueue_event("normal", GameStateMachine.GameState.IDLE, 2)
	GameStateMachine.enqueue_event("force", GameStateMachine.GameState.DISCONNECTED, 0)
	GameStateMachine.enqueue_event("mid", GameStateMachine.GameState.WORKOUT_ACTIVE, 1)

	# Assert — internal queue sorted by priority ascending
	var queue: Array = GameStateMachine.get(QUEUE_VAR)
	assert_eq(queue.size(), 3, "All 3 events enqueued")
	assert_eq(queue[0]["priority"], 0, "Priority 0 must be first")
	assert_eq(queue[1]["priority"], 1, "Priority 1 must be second")
	assert_eq(queue[2]["priority"], 2, "Priority 2 must be last")


## AC-gsm-queue-3: only 1 event drained per _process call.
func test_event_queue_one_per_frame_drain() -> void:
	pending("BLOCKED: GameStateMachine implementation epic — game_state_machine.gd is a Foundation-chain skeleton (awaiting step 5+). Un-pend when GSM is implemented.")
	return  # remove with GSM impl
	# Arrange
	GameStateMachine.enqueue_event("e1", GameStateMachine.GameState.IDLE, 2)
	GameStateMachine.enqueue_event("e2", GameStateMachine.GameState.WORKOUT_ACTIVE, 2)
	GameStateMachine.enqueue_event("e3", GameStateMachine.GameState.DISCONNECTED, 2)

	# Act — 1 frame
	GameStateMachine._process(0.016)

	# Assert — queue size decremented by exactly 1
	var queue: Array = GameStateMachine.get(QUEUE_VAR)
	assert_eq(queue.size(), 2, "Exactly 1 event drained per frame")


## AC-gsm-queue-2: stale event (already in target state) skipped.
func test_event_queue_skips_stale_event() -> void:
	pending("BLOCKED: GameStateMachine implementation epic — game_state_machine.gd is a Foundation-chain skeleton (awaiting step 5+). Un-pend when GSM is implemented.")
	return  # remove with GSM impl
	# Arrange — current state is IDLE, enqueue event targeting IDLE
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.IDLE)
	GameStateMachine.enqueue_event("stale", GameStateMachine.GameState.IDLE, 2)

	var transition_count: int = 0
	GameStateMachine.state_changed.connect(
		func(_f, _t, _p) -> void: transition_count += 1
	)

	# Act
	GameStateMachine._process(0.016)

	# Assert — event drained but no transition fired
	assert_eq(GameStateMachine.get(QUEUE_VAR).size(), 0, "Event dequeued")
	assert_eq(transition_count, 0, "Stale event must NOT trigger transition")


## Additional: empty queue process is a no-op.
func test_event_queue_empty_process_noop() -> void:
	pending("BLOCKED: GameStateMachine implementation epic — game_state_machine.gd is a Foundation-chain skeleton (awaiting step 5+). Un-pend when GSM is implemented.")
	return  # remove with GSM impl
	# Act — process with empty queue
	GameStateMachine._process(0.016)

	# Assert — no errors, queue still empty
	assert_eq(GameStateMachine.get(QUEUE_VAR).size(), 0)
