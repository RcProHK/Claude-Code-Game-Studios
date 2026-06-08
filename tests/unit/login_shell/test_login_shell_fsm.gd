extends GutTest
## Story 004 — Shell 5-state FSM: GSM→shell mapping, auth_required LOGIN interrupt,
## mid-workout banner-defer, cross-fade integrity. Covers AC-03 / AC-24 / AC-38 +
## States table + EC-E1.
##
## GDD: design/gdd/login-gymsys-connection-ui.md States and Transitions + Rule 9(a).
## ADR-0006: shell observes GSM, NEVER requests a transition. Injected-clock timing
## (advance(delta_ms)) — #22/#23 discipline; deterministic, no process_frame await.
## #2 is a STUB (G-LS-3/4 erratum) → auth_required is mock-scoped here.

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")

## Shell state enum mirror (compile-time constants from the SUT).
const S_HIDDEN := CoordinatorScript.ShellState.HIDDEN
const S_LOGIN := CoordinatorScript.ShellState.LOGIN
const S_IDLE := CoordinatorScript.ShellState.SHELL_IDLE
const S_DISC := CoordinatorScript.ShellState.DISCONNECTED_SHELL
const S_DRAIN := CoordinatorScript.ShellState.DRAINING

const FADE: float = CoordinatorScript.SHELL_FADE_MS

const G_BOOTING := GSMScript.GameState.BOOTING
const G_DISCONNECTED := GSMScript.GameState.DISCONNECTED
const G_IDLE := GSMScript.GameState.IDLE
const G_WORKOUT := GSMScript.GameState.WORKOUT_ACTIVE
const G_LOOT := GSMScript.GameState.LOOT_DROP
const G_SUSPENDED := GSMScript.GameState.SUSPENDED


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)

	var current_state: int = 2  # IDLE
	var initial_fire_on_connect: bool = true

	func get_current_state() -> int:
		return current_state

	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		if initial_fire_on_connect:
			callable.call(current_state, current_state, null)

	func emit_transition(to_state: int) -> void:
		var from_state: int = current_state
		current_state = to_state
		state_changed.emit(from_state, to_state, null)


## Mock #2 GymSysBackendClient — the real autoload is a stub with no signals yet.
class MockClient:
	extends Node
	signal auth_required(reason)

	func fire_auth_required(reason = null) -> void:
		auth_required.emit(reason)


class MockPersistence:
	extends Node
	var write_calls: int = 0

	func write(_key: String, _value) -> void:
		write_calls += 1


var _gsm: MockGsm
var _client: MockClient
var _persistence: MockPersistence


func _make(gsm_state: int) -> Node:
	_gsm = MockGsm.new()
	_client = MockClient.new()
	_persistence = MockPersistence.new()
	_gsm.current_state = gsm_state
	add_child_autofree(_gsm)
	add_child_autofree(_client)
	add_child_autofree(_persistence)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._client = _client
	c._persistence = _persistence
	add_child_autofree(c)  # triggers _ready (cfis sentinel fires synchronously)
	return c


## Advance until the FSM reaches its fixed point (settle chain + fades drain).
## Deterministic: the derive function is pure over (auth, draining, gsm), so the
## chain converges in a couple of transitions; 8 ticks is a generous guard.
func _settle(c: Node) -> void:
	for _i in range(8):
		c.advance(FADE)


# --- States table: GSM → shell mapping ---

func test_boot_idle_settles_to_shell_idle() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	assert_eq(c.get_state(), S_IDLE, "GSM IDLE + token → SHELL_IDLE")
	assert_true(c.get_shell_layer().visible, "SHELL_IDLE shows a surface")


func test_boot_disconnected_settles_to_disconnected_shell() -> void:
	var c: Node = _make(G_DISCONNECTED)
	_settle(c)
	assert_eq(c.get_state(), S_DISC, "GSM DISCONNECTED → DISCONNECTED_SHELL")


func test_boot_workout_state_is_hidden() -> void:
	var c: Node = _make(G_WORKOUT)
	_settle(c)
	assert_eq(c.get_state(), S_HIDDEN, "workout-family GSM → HIDDEN (no shell surface)")
	assert_false(c.get_shell_layer().visible, "HIDDEN hides the login layer")


# --- AC-03: auth_required → LOGIN next tick, visible (from any non-workout state) ---

func test_auth_required_enters_login_next_tick_visible() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	assert_eq(c.get_state(), S_IDLE, "precondition SHELL_IDLE")
	_client.fire_auth_required(null)
	c.advance(1.0)  # one tick — the「下一 frame」settle
	assert_eq(c.get_state(), S_LOGIN, "auth_required → LOGIN on the next tick (AC-03)")
	assert_true(c.get_shell_layer().visible, "LoginShellLayer visible on LOGIN entry (AC-03)")


func test_auth_required_from_disconnected_enters_login() -> void:
	var c: Node = _make(G_DISCONNECTED)
	_settle(c)
	_client.fire_auth_required(null)
	_settle(c)
	assert_eq(c.get_state(), S_LOGIN, "auth_required from DISCONNECTED_SHELL → LOGIN (AC-03 edge)")


func test_auth_required_from_hidden_suspended_enters_login() -> void:
	# SUSPENDED is HIDDEN but NOT workout-family → no defer, LOGIN is derivable.
	var c: Node = _make(G_SUSPENDED)
	_settle(c)
	assert_eq(c.get_state(), S_HIDDEN, "precondition HIDDEN (SUSPENDED)")
	_client.fire_auth_required(null)
	_settle(c)
	assert_eq(c.get_state(), S_LOGIN, "auth_required from HIDDEN (SUSPENDED) → LOGIN (AC-03 edge)")


# --- AC-24: idempotent re-enter ---

func test_login_reentry_is_idempotent() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	_client.fire_auth_required(null)
	_settle(c)
	assert_eq(c.get_state(), S_LOGIN, "in LOGIN")
	assert_eq(c.get_login_entry_count(), 1, "entered LOGIN once")
	# Re-fire auth_required while already LOGIN.
	_client.fire_auth_required(null)
	_settle(c)
	assert_eq(c.get_state(), S_LOGIN, "still LOGIN — idempotent (AC-24)")
	assert_eq(c.get_login_entry_count(), 1, "no re-enter / no re-render (AC-24)")


# --- Mid-workout banner-defer (Rule 9a / Pillar 2 binding) ---

func test_mid_workout_auth_required_defers_login() -> void:
	var c: Node = _make(G_WORKOUT)
	_settle(c)
	assert_eq(c.get_state(), S_HIDDEN, "precondition HIDDEN (mid-workout)")
	_client.fire_auth_required(null)
	_settle(c)
	assert_eq(c.get_state(), S_HIDDEN, "auth_required mid-workout does NOT pop the form (Rule 9a)")
	assert_true(c.get_pending_auth_required(), "_pending_auth_required latched (banner-defer)")


# --- AC-38: deferred LOGIN completes when GSM leaves the workout family ---

func test_mid_workout_defer_completes_on_idle() -> void:
	var c: Node = _make(G_WORKOUT)
	_settle(c)
	_client.fire_auth_required(null)
	_settle(c)
	assert_true(c.get_pending_auth_required(), "deferred precondition")
	_gsm.emit_transition(G_IDLE)
	_settle(c)
	assert_eq(c.get_state(), S_LOGIN, "GSM→IDLE completes the defer → LOGIN (AC-38)")
	assert_false(c.get_pending_auth_required(), "pending flag cleared on LOGIN entry (AC-38)")


func test_mid_workout_defer_completes_on_disconnected() -> void:
	var c: Node = _make(G_WORKOUT)
	_settle(c)
	_client.fire_auth_required(null)
	_settle(c)
	_gsm.emit_transition(G_DISCONNECTED)
	_settle(c)
	assert_eq(c.get_state(), S_LOGIN, "GSM→DISCONNECTED also completes the defer → LOGIN (AC-38 / EC-C4)")
	assert_false(c.get_pending_auth_required(), "pending flag cleared (EC-C4 path)")


# --- Cross-fade discipline + EC-E1 (no abort mid-tween) ---

func test_cross_fade_runs_for_shell_fade_ms() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	_client.fire_auth_required(null)
	c.advance(1.0)  # begin fade into LOGIN
	assert_true(c.is_fading(), "cross-fade in flight after entry begins")
	c.advance(FADE)  # elapse the full duration
	assert_false(c.is_fading(), "cross-fade settles within SHELL_FADE_MS")


func test_cross_fade_not_aborted_when_gsm_changes_mid_fade() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	_client.fire_auth_required(null)
	c.advance(1.0)  # _state flips to LOGIN, fade in flight
	assert_eq(c.get_state(), S_LOGIN, "entered LOGIN")
	assert_true(c.is_fading(), "fade in flight")
	# GSM jumps to LOOT_DROP mid-fade.
	_gsm.emit_transition(G_LOOT)
	c.advance(1.0)  # still inside the original fade window
	assert_eq(c.get_state(), S_LOGIN, "fade NOT aborted mid-tween — still LOGIN (EC-E1)")
	# Let everything drain: fade completes → re-derive (auth + LOOT_DROP workout) → HIDDEN.
	_settle(c)
	assert_eq(c.get_state(), S_HIDDEN, "after fade completes, re-derive lands on HIDDEN (EC-E1)")
	assert_false(c.is_fading(), "settled")


# --- States table: LOGIN exit on claim success; DRAINING reachable ---

func test_claim_success_exits_login_to_landing_state() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	_client.fire_auth_required(null)
	_settle(c)
	assert_eq(c.get_state(), S_LOGIN, "in LOGIN")
	c.notify_claim_succeeded()
	_settle(c)
	assert_eq(c.get_state(), S_IDLE, "claim success clears auth → cross-fade to landing SHELL_IDLE")


func test_logout_enters_draining() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	c.request_logout()
	_settle(c)
	assert_eq(c.get_state(), S_DRAIN, "logout → DRAINING (story 014 fills the surface)")


# --- AC-02 regression: zero persist through the whole FSM cycle ---

func test_zero_persist_through_full_fsm_cycle() -> void:
	var c: Node = _make(G_IDLE)
	_settle(c)
	_client.fire_auth_required(null)
	_settle(c)
	c.notify_claim_succeeded()
	_settle(c)
	c.request_logout()
	_settle(c)
	assert_eq(_persistence.write_calls, 0, "the entire shell FSM cycle writes nothing (AC-02 holds under FSM)")
