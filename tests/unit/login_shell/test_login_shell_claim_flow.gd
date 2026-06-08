extends GutTest
## Story 008 — Claim flow (G-LS-3 mock-scoped). Covers AC-06 (anti-double-submit),
## AC-07/08 (yield landing), AC-22 (cancel fallback).
##
## GDD: Rule 3/4. The shell waits for GSM to leave BOOTING before landing (never
## assumes IDLE); a SUSPENDED interrupt or timeout cancels a hung claim (EC-A1).

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const S_LOGIN := CoordinatorScript.ShellState.LOGIN
const S_HIDDEN := CoordinatorScript.ShellState.HIDDEN
const S_IDLE := CoordinatorScript.ShellState.SHELL_IDLE
const FADE: float = CoordinatorScript.SHELL_FADE_MS
const TIMEOUT: float = CoordinatorScript.CLAIM_TIMEOUT_MS

const G_BOOTING := GSMScript.GameState.BOOTING
const G_IDLE := GSMScript.GameState.IDLE
const G_LOOT := GSMScript.GameState.LOOT_DROP
const G_SUSPENDED := GSMScript.GameState.SUSPENDED


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 0  # BOOTING
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
	signal auth_required(reason)
	var auth_required_value: bool = true
	var claim_calls: int = 0
	func is_auth_required() -> bool: return auth_required_value
	func claim_session(_u: String, _p: String) -> void:
		claim_calls += 1


var _gsm: MockGsm
var _client: MockClient


func _make_login(gsm_state: int = G_BOOTING) -> Node:
	# Boot with auth required → boot-sweep enters LOGIN.
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


# --- AC-06: anti-double-submit ---

func test_ac06_submit_disables_and_counts_once() -> void:
	var c := _make_login()
	assert_eq(c.get_state(), S_LOGIN, "in LOGIN (precondition)")
	c.submit_claim("user", "pass")
	assert_true(c.is_claim_loading(), "AC-06: submit → loading (disabled)")
	assert_eq(c.get_claim_session_calls(), 1, "AC-06: claim_session called once")
	assert_eq(_client.claim_calls, 1, "the #2 mock saw one claim")


func test_ac06_rapid_resubmit_is_noop() -> void:
	var c := _make_login()
	c.submit_claim("user", "pass")
	c.submit_claim("user", "pass")  # rapid second tap
	c.submit_claim("user", "pass")
	assert_eq(c.get_claim_session_calls(), 1, "AC-06/EC-A4: re-tap while loading → no-op (calls stays 1)")


# --- AC-07/08: yield landing (never assume IDLE) ---

func test_ac07_success_while_booting_stays_in_login() -> void:
	var c := _make_login(G_BOOTING)
	c.submit_claim("user", "pass")
	c.notify_claim_result(&"success")
	# GSM still BOOTING → shell must NOT jump to a landing state.
	assert_eq(c.get_state(), S_LOGIN, "AC-07: success + GSM BOOTING → stay LOGIN (yield landing)")


func test_ac07_success_then_gsm_idle_lands_shell_idle() -> void:
	var c := _make_login(G_BOOTING)
	c.submit_claim("user", "pass")
	c.notify_claim_result(&"success")
	_gsm.emit_transition(G_IDLE)  # GSM finally leaves BOOTING
	for _i in range(8):
		c.advance(FADE)
	assert_eq(c.get_state(), S_IDLE, "GSM→IDLE after success → land SHELL_IDLE")


func test_ac08_success_then_gsm_loot_drop_goes_hidden_not_idle() -> void:
	var c := _make_login(G_BOOTING)
	c.submit_claim("user", "pass")
	c.notify_claim_result(&"success")
	_gsm.emit_transition(G_LOOT)  # deferred loot reveal lands first
	for _i in range(8):
		c.advance(FADE)
	assert_eq(c.get_state(), S_HIDDEN, "AC-08: success + GSM→LOOT_DROP → HIDDEN, NOT SHELL_IDLE (EC-A5)")


# --- AC-22: cancel fallback (interrupted, not failed) ---

func test_ac22_suspended_cancels_hung_claim() -> void:
	var c := _make_login(G_BOOTING)
	c.submit_claim("user", "pass")
	assert_true(c.is_claim_loading(), "claim in flight")
	_gsm.emit_transition(G_SUSPENDED)  # backgrounded mid-claim, no result
	assert_false(c.is_claim_loading(), "AC-22: claim cancelled → submit re-enabled")
	assert_true(c.get_claim_error_copy().contains("程序中途中斷"), "AC-22: INTERRUPTED copy")
	assert_false(c.get_claim_error_copy().contains("登入失敗"), "AC-22: NOT a login-failure message")


func test_ac22_timeout_cancels_hung_claim() -> void:
	var c := _make_login(G_BOOTING)
	c.submit_claim("user", "pass")
	c.advance(TIMEOUT)  # injected-clock timeout, no result arrived
	assert_false(c.is_claim_loading(), "AC-22: timeout → re-enabled")
	assert_true(c.get_claim_error_copy().contains("程序中途中斷"), "AC-22: INTERRUPTED copy on timeout")


func test_ghost_result_after_cancel_is_ignored() -> void:
	var c := _make_login(G_BOOTING)
	c.submit_claim("user", "pass")
	_gsm.emit_transition(G_SUSPENDED)  # cancel
	c.notify_claim_result(&"success")  # late ghost result
	assert_ne(c.get_state(), S_IDLE, "ghost success after cancel does not land the shell")
