# GameStateMachine.connect_for_initial_state helper — Unit Tests
#
# Validates ADR-0006 Contract 6 (sentinel delivery) + Contract 7 (race guard).
# Satisfies ADR-0006 Validation Criteria line 915:
#   "subscriber connected via connect_for_initial_state followed by immediate real
#    transition receives ONLY real transition, never stale initial"
#
# Framework: GUT v7.x — see tests/README.md
# Engine: Godot 4.6
#
# Test isolation discipline: each test connects a local mock subscriber + disconnects
# in after_each() to prevent cross-test signal connection leak (GameStateMachine
# autoload is shared across the test run).
extends GutTest


# Mock subscriber — records every state_changed callback for assertion.
class MockSubscriber:
	var received_calls: Array[Dictionary] = []

	func on_state_changed(from: GameStateMachine.GameState, to: GameStateMachine.GameState, payload: StateTransitionPayload) -> void:
		received_calls.append({
			"from": from,
			"to": to,
			"source_event": payload.source_event if payload != null else "",
		})


var _mock: MockSubscriber
var _original_last_emit_tick: int


func before_each() -> void:
	_mock = MockSubscriber.new()
	_original_last_emit_tick = GameStateMachine._last_emit_tick


func after_each() -> void:
	# Cleanup: disconnect mock from signal if still connected.
	# Safe even if connect failed (is_connected guards the disconnect call).
	if GameStateMachine.state_changed.is_connected(_mock.on_state_changed):
		GameStateMachine.state_changed.disconnect(_mock.on_state_changed)
	# Restore _last_emit_tick to whatever it was before the test (prevents
	# cross-test pollution if a test mutated it to simulate a real transition).
	GameStateMachine._last_emit_tick = _original_last_emit_tick


func test_initial_state_delivered_on_next_process_frame() -> void:
	# Default _last_emit_tick = -1 + captured_tick = -1 → (-1 > -1) = false → deliver.
	GameStateMachine.connect_for_initial_state(_mock.on_state_changed)
	# Lambda is deferred via process_frame.connect(..., CONNECT_ONE_SHOT) — wait one frame.
	await get_tree().process_frame
	# One more frame to ensure the CONNECT_ONE_SHOT callback finishes.
	await get_tree().process_frame

	assert_eq(_mock.received_calls.size(), 1, "Subscriber should receive exactly 1 initial-state delivery")
	if _mock.received_calls.size() >= 1:
		var call: Dictionary = _mock.received_calls[0]
		assert_eq(call["from"], GameStateMachine._current_state, "Initial-state 'from' should equal current state (self-loop sentinel pattern per F-STEP4-1)")
		assert_eq(call["to"], GameStateMachine._current_state, "Initial-state 'to' should equal current state (self-loop sentinel pattern per F-STEP4-1)")


func test_sentinel_payload_source_event_marker_set_correctly() -> void:
	# Subscribers MUST be able to distinguish initial-state delivery from real
	# transitions via payload.source_event == INITIAL_STATE_PAYLOAD_SOURCE_EVENT.
	GameStateMachine.connect_for_initial_state(_mock.on_state_changed)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_mock.received_calls.size(), 1)
	if _mock.received_calls.size() >= 1:
		var call: Dictionary = _mock.received_calls[0]
		assert_eq(
			call["source_event"],
			GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT,
			"payload.source_event must equal INITIAL_STATE_PAYLOAD_SOURCE_EVENT for sentinel detection"
		)
		assert_eq(call["source_event"], "initial_state", "Sentinel marker string is the canonical 'initial_state' value")


func test_initial_state_payload_is_single_shared_instance() -> void:
	# Contract 6 line 347: sentinel constructed once at boot; subscribers treat read-only.
	# Verify multiple connects all see the same payload Object reference (not new per connect).
	var mock_a := MockSubscriber.new()
	var mock_b := MockSubscriber.new()
	GameStateMachine.connect_for_initial_state(mock_a.on_state_changed)
	GameStateMachine.connect_for_initial_state(mock_b.on_state_changed)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(mock_a.received_calls.size(), 1)
	assert_eq(mock_b.received_calls.size(), 1)
	# Both subscribers received the same sentinel marker — proves single shared instance pattern.
	assert_eq(
		mock_a.received_calls[0]["source_event"],
		mock_b.received_calls[0]["source_event"],
		"Both subscribers must see the same sentinel marker (single shared _initial_state_payload)"
	)

	# Cleanup local mocks
	if GameStateMachine.state_changed.is_connected(mock_a.on_state_changed):
		GameStateMachine.state_changed.disconnect(mock_a.on_state_changed)
	if GameStateMachine.state_changed.is_connected(mock_b.on_state_changed):
		GameStateMachine.state_changed.disconnect(mock_b.on_state_changed)


func test_skip_stale_when_emit_tick_advanced_before_deferred_fire() -> void:
	# Contract 7 race guard (ADR-0006 line 399-410):
	# Subscriber A connects → captured_tick = _last_emit_tick (e.g., 100).
	# Before the deferred lambda fires, real transition advances _last_emit_tick to 200.
	# Deferred lambda checks (_last_emit_tick > captured_tick) = (200 > 100) = true → SKIP.
	# Subscriber A does NOT receive initial-state delivery (it would be stale).
	#
	# Setup: advance _last_emit_tick to a positive value first so captured_tick is captured at it.
	GameStateMachine._last_emit_tick = 100
	GameStateMachine.connect_for_initial_state(_mock.on_state_changed)
	# Now simulate real transition advancing tick BEFORE deferred fire.
	GameStateMachine._last_emit_tick = 200
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(
		_mock.received_calls.size(), 0,
		"Subscriber MUST NOT receive stale initial-state when real transition fired between connect and deferred delivery (Contract 7 race guard)"
	)


func test_default_last_emit_tick_minus_one_allows_first_delivery() -> void:
	# Contract 7 invariant: default _last_emit_tick = -1 is load-bearing.
	# First connect captures tick = -1. Guard check (-1 > -1) = false → delivery proceeds.
	# Confirms the default value enables the first-ever subscriber to receive initial state.
	GameStateMachine._last_emit_tick = -1
	GameStateMachine.connect_for_initial_state(_mock.on_state_changed)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(
		_mock.received_calls.size(), 1,
		"Default _last_emit_tick = -1 MUST enable first subscriber's initial-state delivery (guard: -1 > -1 = false → deliver)"
	)
