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
	# Arrange — handler that tries to re-enter the transition primitive while
	# still inside the `state_changed` emit. The re-entry must be rejected with
	# dropped_event("lock_held") because the generational lock is held during
	# emit. Verified via GUT watch_signals: a capture-by-value counter mutated
	# inside a connected lambda would NOT survive to the outer assert.
	watch_signals(GameStateMachine)
	GameStateMachine.state_changed.connect(
		func(_f: int, _t: int, _p: StateTransitionPayload) -> void:
			# Synchronous re-entry attempt — lock is held during emit.
			GameStateMachine._request_transition("reentry_attempt", GameStateMachine.GameState.IDLE)
	)

	# Act — original transition
	GameStateMachine._request_transition("test_event", GameStateMachine.GameState.IDLE)

	# Assert — re-entry was rejected with lock_held reason
	assert_signal_emit_count(GameStateMachine, "dropped_event", 1,
		"AC-04a: synchronous re-entry must emit dropped_event exactly once")
	var drop_params: Array = get_signal_parameters(GameStateMachine, "dropped_event")
	assert_eq(drop_params[1], "lock_held", "AC-04a: drop reason must be 'lock_held'")


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
	# Arrange — handler that DEFERS re-entry via process_frame.connect ONE_SHOT.
	# deferred_fired is array-wrapped: GDScript lambdas capture locals BY VALUE,
	# so a scalar counter mutated inside the nested lambda would not survive to
	# the outer assert. An Array element mutation IS visible (reference type).
	var deferred_fired: Array[int] = [0]
	# Stored so it can be DISCONNECTED after the test. GameStateMachine is a real autoload that
	# outlives this test; an un-disconnected lambda leaks — on a LATER test's GSM transition the
	# autoload's _process re-fires it, and its inner get_tree() (on this now-freed test node)
	# returns null, surfacing a spurious "Unexpected Error" against whatever test owns that frame.
	var outer_handler := func(_f: int, _t: int, _p: StateTransitionPayload) -> void:
		get_tree().process_frame.connect(
			func() -> void:
				deferred_fired[0] += 1
				# By the time this fires, the original transition's lock is released.
				# Verify the lock is free (we don't need to re-call to prove the pattern).
				assert_false(
					GameStateMachine.get(TRANSITIONING_VAR),
					"AC-32a: by deferred fire time, lock must be released"
				),
			CONNECT_ONE_SHOT
		)
	GameStateMachine.state_changed.connect(outer_handler)

	# Act
	GameStateMachine._request_transition("test", GameStateMachine.GameState.IDLE)
	await get_tree().process_frame
	await get_tree().process_frame  # ensure the deferred lambda landed

	# Cleanup — disconnect from the autoload so the lambda cannot leak into later tests.
	if GameStateMachine.state_changed.is_connected(outer_handler):
		GameStateMachine.state_changed.disconnect(outer_handler)

	# Assert
	assert_eq(deferred_fired[0], 1, "AC-32a: deferred re-entry must fire exactly once")
