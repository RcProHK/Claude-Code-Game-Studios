## Integration tests for StreakSystemScript Story 001 — State Machine + Boot Subscription.
##
## Covers:
##   AC-ss-sm-1: boot sets BOOTING then drains deferred events + transitions to READY
##   AC-ss-sm-2: subscription uses connect_for_initial_state (not direct state_changed.connect)
##   AC-ss-sm-3: legal arcs succeed; illegal arcs emit signal, state unchanged
##
## Story: production/epics/streak-system/story-001-state-machine-boot.md
## Test evidence path: tests/integration/streak/test_state_machine_boot.gd
extends GutTest
const StreakSystemScript := preload("res://src/autoload/streak_system.gd")


## Mock GameStateMachine — tracks connect_for_initial_state calls.
##
## ADR-0006 Contract 6 protection note:
##   If production code mistakenly calls `_gsm.state_changed.connect(...)` directly,
##   this mock has no `state_changed` signal, causing a runtime error that fails the test.
##   That runtime-error path IS the Contract 6 protection — no explicit counter needed.
class MockGSM extends RefCounted:
	## Number of times connect_for_initial_state was called (expect: 1).
	var connect_for_initial_state_call_count: int = 0
	## The callable registered via connect_for_initial_state.
	var registered_callable: Callable = Callable()

	func connect_for_initial_state(callable: Callable) -> void:
		connect_for_initial_state_call_count += 1
		registered_callable = callable

	## Simulate the real GSM's deferred self-loop sentinel delivery
	## (ADR-0006 Contract 6 Addendum): callv([state, state, payload]) with
	## payload.source_event == "initial_state". Exercises the subscriber's
	## _on_gsm_state_changed handler with the exact arg layout real GSM uses,
	## validating the GameState/payload typed-callv signature compatibility.
	func deliver_initial_state(state: GameStateMachine.GameState) -> void:
		var payload := StateTransitionPayload.new()
		payload.source_event = GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT
		registered_callable.callv([state, state, payload])


## Minimal mock PersistenceLayer — satisfies the _ready() critical_save_failed
## connect + keeps boot tests hermetic (no real autoload coupling).
class StubPersistence extends RefCounted:
	signal critical_save_failed(error_code: String, key: String)
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


## Helper: build a StreakSystemScript instance with mock GSM + mock PersistenceLayer injected.
func _make_streak(mock_gsm: MockGSM) -> StreakSystemScript:
	var streak := StreakSystemScript.new()
	streak._gsm = mock_gsm
	streak._persistence = StubPersistence.new()
	return streak


# ---------------------------------------------------------------------------
# AC-ss-sm-1: boot starts BOOTING, drains deferred events, arrives at READY
# ---------------------------------------------------------------------------

func test_substate_is_booting_before_ready_and_ready_after() -> void:
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)

	# _substate must be BOOTING before _ready() runs
	assert_eq(
		streak._substate,
		StreakSystemScript.Substate.BOOTING,
		"_substate must be BOOTING on construction (before _ready)"
	)

	add_child_autofree(streak)  # triggers _ready()

	assert_eq(
		streak._substate,
		StreakSystemScript.Substate.READY,
		"_substate must be READY after _ready() completes"
	)


func test_deferred_events_are_drained_during_boot() -> void:
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)

	# Queue a deferred event before _ready() runs. Array-wrapped: GDScript lambdas
	# capture scalars by value, so a plain `was_called: bool` would never update.
	var was_called := [false]
	streak._deferred_events.append(func() -> void: was_called[0] = true)

	add_child_autofree(streak)

	assert_true(was_called[0], "Deferred event must be called during _drain_deferred_if_any()")
	assert_eq(streak._deferred_events.size(), 0, "Deferred event queue must be empty after drain")


# ---------------------------------------------------------------------------
# AC-ss-sm-2: subscription uses connect_for_initial_state, not direct connect
# ---------------------------------------------------------------------------

func test_subscription_uses_connect_for_initial_state() -> void:
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)

	add_child_autofree(streak)

	assert_eq(
		mock_gsm.connect_for_initial_state_call_count,
		1,
		"connect_for_initial_state must be called exactly once during _ready()"
	)
	assert_true(
		mock_gsm.registered_callable.is_valid(),
		"A valid callable must be registered via connect_for_initial_state"
	)
	# ADR-0006 Contract 6 note: if production code used state_changed.connect() directly,
	# MockGSM has no state_changed signal — test would runtime-error. That is the protection.


func test_initial_state_sentinel_delivery_does_not_change_substate() -> void:
	# AC-ss-sm-2: "WHEN GSM delivers initial state via connect_for_initial_state".
	# Exercises _on_gsm_state_changed with the real GSM callv arg layout
	# ([state, state, sentinel_payload]) — validates the GameState/payload typed
	# signature and the sentinel early-return path (ADR-0006 Contract 6 Addendum).
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)
	add_child_autofree(streak)  # boots to READY, registers the callable

	mock_gsm.deliver_initial_state(GameStateMachine.GameState.IDLE)

	assert_eq(
		streak._substate,
		StreakSystemScript.Substate.READY,
		"Initial-state sentinel delivery must NOT change _substate (handler early-returns)"
	)


# ---------------------------------------------------------------------------
# AC-ss-sm-3: legal arcs succeed; illegal arcs emit signal, state unchanged
# ---------------------------------------------------------------------------

func test_boot_emits_substate_changed_booting_to_ready() -> void:
	# AC-ss-sm-3 (observable side effect): boot's BOOTING→READY arc must emit
	# substate_changed with the correct from/to — not just mutate _substate.
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)
	watch_signals(streak)  # must watch BEFORE _ready() fires the boot transition

	add_child_autofree(streak)  # triggers _ready() → BOOTING→READY

	assert_signal_emitted_with_parameters(
		streak,
		"substate_changed",
		[StreakSystemScript.Substate.BOOTING, StreakSystemScript.Substate.READY]
	)


func test_legal_transition_emits_substate_changed_with_correct_params() -> void:
	# AC-ss-sm-3 (observable side effect): a legal transition must emit
	# substate_changed with correct from/to params (symmetry with illegal path).
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)
	add_child_autofree(streak)  # boots to READY
	watch_signals(streak)

	streak._transition_to(StreakSystemScript.Substate.UPDATING)

	assert_signal_emitted_with_parameters(
		streak,
		"substate_changed",
		[StreakSystemScript.Substate.READY, StreakSystemScript.Substate.UPDATING]
	)


func test_legal_arcs_transition_successfully() -> void:
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)
	add_child_autofree(streak)  # boots to READY

	# READY → UPDATING
	streak._transition_to(StreakSystemScript.Substate.UPDATING)
	assert_eq(streak._substate, StreakSystemScript.Substate.UPDATING, "READY→UPDATING must succeed")

	# UPDATING → FAILED
	streak._transition_to(StreakSystemScript.Substate.FAILED)
	assert_eq(streak._substate, StreakSystemScript.Substate.FAILED, "UPDATING→FAILED must succeed")

	# FAILED → BACKOFF
	streak._transition_to(StreakSystemScript.Substate.BACKOFF)
	assert_eq(streak._substate, StreakSystemScript.Substate.BACKOFF, "FAILED→BACKOFF must succeed")

	# BACKOFF → READY
	streak._transition_to(StreakSystemScript.Substate.READY)
	assert_eq(streak._substate, StreakSystemScript.Substate.READY, "BACKOFF→READY must succeed")

	# READY → UPDATING → READY (cycle)
	streak._transition_to(StreakSystemScript.Substate.UPDATING)
	streak._transition_to(StreakSystemScript.Substate.READY)
	assert_eq(streak._substate, StreakSystemScript.Substate.READY, "UPDATING→READY must succeed")


func test_illegal_arcs_emit_signal_and_leave_state_unchanged() -> void:
	var mock_gsm := MockGSM.new()
	var streak := _make_streak(mock_gsm)
	add_child_autofree(streak)  # boots to READY

	# Watch invalid_transition_attempted (NOT lambda counters — GDScript captures
	# scalars by value, so invalid_from / signal_count would never update).
	watch_signals(streak)

	# Test READY → BOOTING (illegal)
	streak._transition_to(StreakSystemScript.Substate.BOOTING)
	assert_eq(streak._substate, StreakSystemScript.Substate.READY, "READY→BOOTING must NOT change state")
	assert_signal_emit_count(streak, "invalid_transition_attempted", 1,
		"invalid_transition_attempted must emit once for illegal arc")
	var p: Array = get_signal_parameters(streak, "invalid_transition_attempted")
	assert_eq(p[0], StreakSystemScript.Substate.READY, "Signal 'from' must be READY")
	assert_eq(p[1], StreakSystemScript.Substate.BOOTING, "Signal 'to' must be BOOTING")

	# Test READY → FAILED (illegal — must go via UPDATING)
	streak._transition_to(StreakSystemScript.Substate.FAILED)
	assert_eq(streak._substate, StreakSystemScript.Substate.READY, "READY→FAILED must NOT change state")
	assert_signal_emit_count(streak, "invalid_transition_attempted", 2,
		"invalid_transition_attempted must emit again")
