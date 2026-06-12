# Telemetry (#28) — Story 002: autoload scaffold + 5-state FSM + connect_for_initial_state.
#
# Verifies:
#   AC-1  FSM legal transitions reachable; illegal transitions rejected (state unchanged);
#         same-state re-entry is a no-op; a FAILED flush converges to ACTIVE (never error).
#   AC-2  connect_for_initial_state back-fills the current GSM state on late boot
#         (mock GSM current_state = COMBAT_ACTIVE) and BOOTING → ACTIVE after subscribe.
#   AC-3  Telemetry declares ZERO custom (gameplay) signals (G-TEL-2 runtime assertion;
#         the static lint is Story 013).
#
# Telemetry has no class_name (it is an autoload), so the SUT is loaded via preload
# (reference_gut_filename_convention). FSM-only cases use a non-added instance (pure
# logic, no tree); the cfis case adds the instance so _ready() + deferred delivery run.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")

## GSM GameState ordinal for COMBAT_ACTIVE (game_state_machine.gd enum GameState).
const COMBAT_ACTIVE: int = 5


## Minimal stand-in for #1 GameStateMachine: replays the cfis contract (connect the
## handler to state_changed + deliver the captured initial state deferred on the next
## process_frame, mirroring the real CONNECT_ONE_SHOT). Needs a tree for process_frame.
class MockGSM extends Node:
	signal state_changed(from_state, to_state, payload)
	var mock_current_state: int = -1

	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		var captured := mock_current_state
		get_tree().process_frame.connect(
			# Story 002 does not deref payload; null is sufficient (Story 003 passes a
			# real StateTransitionPayload once the envelope reads transition_id).
			func() -> void: callable.call(captured, captured, null),
			CONNECT_ONE_SHOT
		)

	func get_current_state() -> int:
		return mock_current_state


# --- AC-1: FSM transitions ----------------------------------------------------

func test_fsm_legal_transitions_are_reachable() -> void:
	# Arrange
	var S := TelemetryScript.State
	var t = TelemetryScript.new()  # not added — _state stays at init BOOTING

	# Act + Assert: every legal directed edge in the transition table.
	assert_eq(t.get_state(), S.BOOTING, "init state is BOOTING")
	assert_true(t._transition_to(S.ACTIVE), "BOOTING→ACTIVE legal")
	assert_true(t._transition_to(S.FLUSHING), "ACTIVE→FLUSHING legal")
	assert_true(t._transition_to(S.ACTIVE), "FLUSHING→ACTIVE legal")
	assert_true(t._transition_to(S.SUSPENDED), "ACTIVE→SUSPENDED legal")
	assert_true(t._transition_to(S.ACTIVE), "SUSPENDED→ACTIVE legal")
	assert_true(t._transition_to(S.DEGRADED), "ACTIVE→DEGRADED legal")
	assert_true(t._transition_to(S.ACTIVE), "DEGRADED→ACTIVE legal")

	t.free()


func test_fsm_illegal_transitions_are_rejected_and_state_unchanged() -> void:
	# Arrange
	var S := TelemetryScript.State
	var t = TelemetryScript.new()

	# From BOOTING, only ACTIVE is legal.
	assert_false(t._transition_to(S.FLUSHING), "BOOTING→FLUSHING illegal")
	assert_eq(t.get_state(), S.BOOTING, "rejected transition leaves state unchanged")
	assert_false(t._transition_to(S.SUSPENDED), "BOOTING→SUSPENDED illegal")
	assert_false(t._transition_to(S.DEGRADED), "BOOTING→DEGRADED illegal")

	# Move to ACTIVE, then probe its illegal edges.
	assert_true(t._transition_to(S.ACTIVE))
	assert_false(t._transition_to(S.BOOTING), "ACTIVE→BOOTING illegal (no return to boot)")
	assert_eq(t.get_state(), S.ACTIVE, "rejected ACTIVE→BOOTING leaves ACTIVE")

	# From FLUSHING, only ACTIVE is legal.
	assert_true(t._transition_to(S.FLUSHING))
	assert_false(t._transition_to(S.SUSPENDED), "FLUSHING→SUSPENDED illegal")
	assert_false(t._transition_to(S.DEGRADED), "FLUSHING→DEGRADED illegal")
	assert_eq(t.get_state(), S.FLUSHING, "rejected transitions leave FLUSHING")

	t.free()


func test_fsm_same_state_reentry_is_noop() -> void:
	var S := TelemetryScript.State
	var t = TelemetryScript.new()
	assert_true(t._transition_to(S.ACTIVE))
	assert_false(t._transition_to(S.ACTIVE), "same-state re-entry returns false (no-op)")
	assert_eq(t.get_state(), S.ACTIVE, "re-entry leaves state ACTIVE")
	t.free()


func test_failed_flush_returns_to_active_never_error() -> void:
	# A failed flush must NOT enter an error state — it converges to ACTIVE so the
	# buffer is kept + backoff scheduled (Story 011). Telemetry never lets a dead
	# backend affect gameplay (telemetry.md L104).
	var S := TelemetryScript.State
	var t = TelemetryScript.new()
	assert_true(t._transition_to(S.ACTIVE))
	assert_true(t._transition_to(S.FLUSHING), "ACTIVE→FLUSHING")
	assert_true(t.notify_flush_finished(false), "failed flush returns FLUSHING→ACTIVE")
	assert_eq(t.get_state(), S.ACTIVE, "failed flush stays ACTIVE (buffer kept, no error state)")
	# Idempotent: notify when not flushing is a no-op.
	assert_false(t.notify_flush_finished(true), "notify_flush_finished is a no-op outside FLUSHING")
	t.free()


func test_successful_flush_also_returns_to_active() -> void:
	var S := TelemetryScript.State
	var t = TelemetryScript.new()
	assert_true(t._transition_to(S.ACTIVE))
	assert_true(t._transition_to(S.FLUSHING))
	assert_true(t.notify_flush_finished(true), "successful flush returns FLUSHING→ACTIVE")
	assert_eq(t.get_state(), S.ACTIVE, "ACK flush converges to ACTIVE")
	t.free()


# --- AC-2: connect_for_initial_state back-fill --------------------------------

func test_cfis_backfills_current_game_state_on_late_boot() -> void:
	# Arrange: mock GSM already in COMBAT_ACTIVE; telemetry joins late (boots Last).
	var mock := MockGSM.new()
	mock.mock_current_state = COMBAT_ACTIVE
	add_child_autofree(mock)  # mock needs a tree for the deferred process_frame delivery
	var t = TelemetryScript.new()
	t._gsm = mock  # inject seam BEFORE _ready (DI override wins over autoload resolve)

	# Act: add → _ready() runs → cfis connects; initial state arrives next process_frame.
	add_child_autofree(t)
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert
	assert_eq(t.get_current_game_state(), COMBAT_ACTIVE,
		"AC-2: cfis back-fills current GSM state (COMBAT_ACTIVE) — not waiting for next change")
	assert_eq(t.get_state(), TelemetryScript.State.ACTIVE,
		"AC-2: BOOTING→ACTIVE after subscribe completes")


func test_current_game_state_is_sentinel_before_backfill() -> void:
	# Before any GSM delivery, the stamp is the sentinel (envelope → "UNKNOWN", EC-10).
	var t = TelemetryScript.new()
	assert_eq(t.get_current_game_state(), TelemetryScript.SENTINEL_GAME_STATE,
		"current_game_state is SENTINEL until first cfis back-fill")
	t.free()


# --- AC-3: no gameplay emit ---------------------------------------------------

func test_telemetry_declares_zero_custom_signals() -> void:
	# G-TEL-2 runtime assertion: Telemetry's signal surface must equal a bare Node's —
	# i.e. it declares NO custom (gameplay) signals. The static lint is Story 013.
	var t = TelemetryScript.new()
	var base := Node.new()
	var base_names := {}
	for s in base.get_signal_list():
		base_names[s.name] = true
	var custom: Array = []
	for s in t.get_signal_list():
		if not base_names.has(s.name):
			custom.append(s.name)
	assert_eq(custom, [],
		"AC-3/G-TEL-2: Telemetry must declare ZERO custom (gameplay) signals — found: %s" % str(custom))
	t.free()
	base.free()
