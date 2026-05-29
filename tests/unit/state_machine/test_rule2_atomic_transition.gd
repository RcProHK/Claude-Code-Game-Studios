# GameStateMachine — Story 002 AC-04a/04b/04c/32a Rule 2 Atomic Transition
#
# Scope: verifies the ADR-0006 Contract 1 generational lock + dropped_event
# semantics. Tests cover:
#   AC-04a: re-entry from `state_changed` handler emits dropped_event("lock_held")
#   AC-04b: post-transition state — _lock_gen incremented, _transitioning=false
#   AC-04c: stale fallback timer (captured_gen != _lock_gen) does NOT clear lock
#   AC-32a: deferred re-entry via process_frame fires after lock release
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 1 (generational lock)
extends GutTest


const STATE_VAR: StringName = &"_current_state"
const LOCK_GEN_VAR: StringName = &"_lock_gen"
const TRANSITIONING_VAR: StringName = &"_transitioning"


func before_each() -> void:
	# Reset GSM to a known baseline before each test. _force_clear_lock
	# (Story 002 internal helper) is the only path that can release a stuck
	# lock without violating the public API; tests use direct set() for speed.
	GameStateMachine.set(STATE_VAR, GameStateMachine.GameState.BOOTING)
	GameStateMachine.set(TRANSITIONING_VAR, false)
	GameStateMachine.clear_spies()
	for conn in GameStateMachine.state_changed.get_connections():
		GameStateMachine.state_changed.disconnect(conn.callable)
	for conn in GameStateMachine.dropped_event.get_connections():
		GameStateMachine.dropped_event.disconnect(conn.callable)


# ===========================================================================
# AC-04a: synchronous re-entry from state_changed handler → dropped_event
# ===========================================================================

func test_rule2_synchronous_reentry_emits_dropped_event() -> void:
	pending("BLOCKED: GameStateMachine implementation epic — game_state_machine.gd is a Foundation-chain skeleton (awaiting step 5+). Un-pend when GSM is implemented.")
	return  # remove with GSM impl
	# Arrange — handler that tries to re-enter the transition primitive
	# while still inside the `state_changed` emit.
	var drop_count: int = 0
	var drop_reason: String = ""
	GameStateMachine.dropped_event.connect(
		func(_e: Variant, reason: String) -> void:
			drop_count += 1
			drop_reason = reason
	)
	GameStateMachine.state_changed.connect(
		func(_f: int, _t: int, _p: StateTransitionPayload) -> void:
			# Synchronous re-entry attempt — lock is held during emit.
			GameStateMachine._request_transition("reentry_attempt", GameStateMachine.GameState.IDLE)
	)

	# Act — original transition
	GameStateMachine._request_transition("test_event", GameStateMachine.GameState.IDLE)

	# Assert — re-entry was rejected with lock_held reason
	assert_eq(drop_count, 1, "AC-04a: synchronous re-entry must emit dropped_event exactly once")
	assert_eq(drop_reason, "lock_held", "AC-04a: drop reason must be 'lock_held'")


# ===========================================================================
# AC-04b: post-transition state — _lock_gen incremented, _transitioning=false
# ===========================================================================

func test_rule2_post_transition_lock_gen_incremented() -> void:
	# Arrange
	var initial_gen: int = GameStateMachine.get(LOCK_GEN_VAR)

	# Act
	GameStateMachine._request_transition("test", GameStateMachine.GameState.IDLE)

	# Assert
	assert_eq(
		GameStateMachine.get(LOCK_GEN_VAR),
		initial_gen + 1,
		"AC-04b: _lock_gen must increment by exactly 1 per successful transition"
	)


func test_rule2_post_transition_transitioning_flag_false() -> void:
	# Act
	GameStateMachine._request_transition("test", GameStateMachine.GameState.IDLE)

	# Assert
	assert_false(
		GameStateMachine.get(TRANSITIONING_VAR),
		"AC-04b: _transitioning must be false after completion"
	)


func test_rule2_state_actually_changed() -> void:
	# Act
	GameStateMachine._request_transition("test", GameStateMachine.GameState.IDLE)

	# Assert
	assert_eq(
		GameStateMachine.get_current_state(),
		GameStateMachine.GameState.IDLE,
		"AC-04b: state must reflect the transition target"
	)


# ===========================================================================
# AC-04c: stale fallback timer (captured_gen != _lock_gen) does NOT clear lock
# ===========================================================================

func test_rule2_stale_timer_does_not_clear_newer_lock() -> void:
	# Arrange — simulate a stale timer firing for an old generation while a
	# new transition's lock is held. We call _force_clear_lock directly with
	# a captured_gen that doesn't match the current _lock_gen.
	GameStateMachine._request_transition("first", GameStateMachine.GameState.IDLE)
	var first_gen: int = GameStateMachine.get(LOCK_GEN_VAR)
	# Simulate new transition in flight: bump _lock_gen + set _transitioning=true
	GameStateMachine.set(LOCK_GEN_VAR, first_gen + 1)
	GameStateMachine.set(TRANSITIONING_VAR, true)

	# Act — stale timer (captured the OLD generation) fires
	GameStateMachine._force_clear_lock(first_gen)

	# Assert — newer lock NOT cleared
	assert_true(
		GameStateMachine.get(TRANSITIONING_VAR),
		"AC-04c: stale timer must NOT clear newer-generation lock"
	)


func test_rule2_matching_timer_does_clear_held_lock() -> void:
	# Arrange — set up a stuck-lock scenario where the timer is the safety net
	var stuck_gen: int = 42
	GameStateMachine.set(LOCK_GEN_VAR, stuck_gen)
	GameStateMachine.set(TRANSITIONING_VAR, true)

	# Act — timer with matching generation fires
	GameStateMachine._force_clear_lock(stuck_gen)

	# Assert — lock cleared
	assert_false(
		GameStateMachine.get(TRANSITIONING_VAR),
		"AC-04c (inverse): matching-generation timer MUST clear a stuck lock"
	)


# ===========================================================================
# AC-32a: deferred re-entry via process_frame fires correctly
# ===========================================================================

func test_rule2_deferred_reentry_fires_after_lock_release() -> void:
	pending("BLOCKED: GameStateMachine implementation epic — game_state_machine.gd is a Foundation-chain skeleton (awaiting step 5+). Un-pend when GSM is implemented.")
	return  # remove with GSM impl
	# Arrange — handler that DEFERS re-entry via process_frame.connect ONE_SHOT.
	var deferred_fired: int = 0
	GameStateMachine.state_changed.connect(
		func(_f: int, _t: int, _p: StateTransitionPayload) -> void:
			get_tree().process_frame.connect(
				func() -> void:
					deferred_fired += 1
					# By the time this fires, the original transition's lock is released.
					# Verify the lock is free (we don't need to re-call to prove the pattern).
					assert_false(
						GameStateMachine.get(TRANSITIONING_VAR),
						"AC-32a: by deferred fire time, lock must be released"
					),
				CONNECT_ONE_SHOT
			)
	)

	# Act
	GameStateMachine._request_transition("test", GameStateMachine.GameState.IDLE)
	await get_tree().process_frame
	await get_tree().process_frame  # ensure the deferred lambda landed

	# Assert
	assert_eq(deferred_fired, 1, "AC-32a: deferred re-entry must fire exactly once")
