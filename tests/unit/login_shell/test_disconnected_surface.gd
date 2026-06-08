extends GutTest
## Story 012 — DISCONNECTED surface + reconnect. Covers AC-37 (workout drop → HIDDEN +
## peripheral banner), AC-37b (reconnect → request_immediate_poll), non-workout →
## DISCONNECTED_SHELL, and EC-C1 (flicker-free toggle).
##
## GDD: Rule 9. A mid-workout drop must NOT pop a full-screen surface (it may resume);
## a non-workout disconnect surfaces the local-view DISCONNECTED_SHELL (never greyed).

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")

const S_HIDDEN := CoordinatorScript.ShellState.HIDDEN
const S_IDLE := CoordinatorScript.ShellState.SHELL_IDLE
const S_DISC := CoordinatorScript.ShellState.DISCONNECTED_SHELL
const FADE: float = CoordinatorScript.SHELL_FADE_MS

const G_IDLE := GSMScript.GameState.IDLE
const G_WORKOUT := GSMScript.GameState.WORKOUT_ACTIVE
const G_DISCONNECTED := GSMScript.GameState.DISCONNECTED


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 2
	var initial_fire_on_connect: bool = true
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		if initial_fire_on_connect:
			callable.call(current_state, current_state, null)
	func emit_transition(to_state: int) -> void:
		var f := current_state
		current_state = to_state
		state_changed.emit(f, to_state, null)


class MockClient:
	extends Node
	var poll_calls: int = 0
	func is_auth_required() -> bool: return false
	func request_immediate_poll() -> void: poll_calls += 1


var _gsm: MockGsm
var _client: MockClient


func _make(gsm_state: int) -> Node:
	_gsm = MockGsm.new()
	_client = MockClient.new()
	_gsm.current_state = gsm_state
	add_child_autofree(_gsm)
	add_child_autofree(_client)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._client = _client
	add_child_autofree(c)
	return c


func _settle(c: Node) -> void:
	for _i in range(8):
		c.advance(FADE)


# --- AC-37: workout drop → stay HIDDEN + peripheral banner ---

func test_ac37_workout_to_disconnected_stays_hidden_with_banner() -> void:
	var c := _make(G_WORKOUT)
	_settle(c)
	assert_eq(c.get_state(), S_HIDDEN, "precondition HIDDEN (workout)")
	_gsm.emit_transition(G_DISCONNECTED)  # mid-workout drop (from WORKOUT_ACTIVE)
	_settle(c)
	assert_eq(c.get_state(), S_HIDDEN, "AC-37: stay HIDDEN (no full-screen DISCONNECTED_SHELL)")
	assert_true(c.is_workout_disconnect(), "workout-disconnect flag set")
	assert_true(c.get_banner_layer().visible, "AC-37: peripheral disconnect banner visible")
	assert_eq(c.get_banner_stack().main_slot()["severity"], ESM.Severity.DISCONNECTED, "DISCONNECTED status banner")


# --- AC-37b: reconnect → request_immediate_poll (no self-backoff) ---

func test_ac37b_reconnect_requests_immediate_poll() -> void:
	var c := _make(G_WORKOUT)
	_settle(c)
	_gsm.emit_transition(G_DISCONNECTED)
	_settle(c)
	c.request_reconnect()  # tap「再試一次」
	assert_eq(_client.poll_calls, 1, "AC-37b: request_immediate_poll() called once")


# --- non-workout disconnect → DISCONNECTED_SHELL ---

func test_non_workout_disconnect_surfaces_shell() -> void:
	var c := _make(G_IDLE)
	_settle(c)
	assert_eq(c.get_state(), S_IDLE, "precondition SHELL_IDLE")
	_gsm.emit_transition(G_DISCONNECTED)  # from IDLE (non-workout)
	_settle(c)
	assert_eq(c.get_state(), S_DISC, "non-workout disconnect → DISCONNECTED_SHELL")
	assert_false(c.is_workout_disconnect(), "not a workout-disconnect")


# --- EC-C1: flicker-free toggle; banner clears on reconnect ---

func test_ec_c1_disconnected_idle_toggle_settles_cleanly() -> void:
	var c := _make(G_IDLE)
	_settle(c)
	for _i in range(3):
		_gsm.emit_transition(G_DISCONNECTED)
		_settle(c)
		assert_eq(c.get_state(), S_DISC, "DISCONNECTED_SHELL on disconnect")
		_gsm.emit_transition(G_IDLE)
		_settle(c)
		assert_eq(c.get_state(), S_IDLE, "SHELL_IDLE on reconnect — no flicker")
	assert_false(c.get_banner_layer().visible, "banner cleared after final reconnect")


func test_disconnect_banner_clears_when_workout_resumes() -> void:
	var c := _make(G_WORKOUT)
	_settle(c)
	_gsm.emit_transition(G_DISCONNECTED)
	_settle(c)
	assert_true(c.get_banner_layer().visible, "banner up during drop")
	_gsm.emit_transition(G_WORKOUT)  # reconnect, workout resumes
	_settle(c)
	assert_false(c.get_banner_layer().visible, "banner cleared when workout resumes")
	assert_false(c.is_workout_disconnect(), "flag cleared")
