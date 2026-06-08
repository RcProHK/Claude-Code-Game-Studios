extends GutTest
## Story 014 — Logout drain (optimistic + non-blocking + part-fail persistent). Covers
## AC-41 (optimistic logout), AC-42 (part-fail persistent), drain success auto-expire
## (EC-B8), and the LOGIN-entry sequencing.
##
## GDD: Rule 12. Logout is optimistic (instant「已登出」) + background drain; a part-fail
## becomes a persistent WIPE-weight banner (never silent — #2 tombstone「會試返」is true).

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")
const ShellFormulas := preload("res://src/ui/login_shell/shell_formulas.gd")

const S_DRAIN := CoordinatorScript.ShellState.DRAINING
const D_NONE := CoordinatorScript.DrainState.NONE
const D_DRAINING := CoordinatorScript.DrainState.DRAINING
const D_SUCCESS := CoordinatorScript.DrainState.SUCCESS
const D_PARTFAIL := CoordinatorScript.DrainState.PARTFAIL
const FADE: float = CoordinatorScript.SHELL_FADE_MS
const G_IDLE := GSMScript.GameState.IDLE

const CLOCK0: int = 100000


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


class MockClient:
	extends Node
	signal drain_started(item_count)
	signal drain_completed(saved, failed)
	var clear_calls: int = 0
	var clear_reason: StringName = &""
	func is_auth_required() -> bool: return false
	func clear_session_token(reason) -> void:
		clear_calls += 1
		clear_reason = reason


var _client: MockClient


func _make() -> Node:
	var gsm := MockGsm.new()
	gsm.current_state = G_IDLE
	_client = MockClient.new()
	add_child_autofree(gsm)
	add_child_autofree(_client)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._client = _client
	c._clock_override_ms = CLOCK0
	add_child_autofree(c)
	for _i in range(8):
		c.advance(FADE)
	return c


# --- AC-41: optimistic logout ---

func test_ac41_logout_optimistic_clears_token_and_banners() -> void:
	var c := _make()
	c.request_logout()
	assert_eq(_client.clear_calls, 1, "AC-41: clear_session_token called immediately")
	assert_eq(_client.clear_reason, &"USER_EXPLICIT", "AC-41: reason USER_EXPLICIT")
	assert_eq(c.get_drain_state(), D_DRAINING, "AC-41: DRAINING")
	assert_false(c.get_banner_stack().get_drain_entry().is_empty(), "AC-41:「已登出」drain banner present")
	assert_true(c.get_banner_layer().visible, "drain banner surfaced")
	for _i in range(8):
		c.advance(FADE)
	assert_eq(c.get_state(), S_DRAIN, "AC-41: shell enters DRAINING (no blocking modal)")


# --- AC-42: part-fail → persistent WIPE-weight banner ---

func test_ac42_drain_completed_partfail_persistent_wipe() -> void:
	var c := _make()
	c.request_logout()
	_client.drain_completed.emit(5, 2)  # 5 saved, 2 failed
	assert_eq(c.get_drain_state(), D_PARTFAIL, "AC-42: PARTFAIL")
	assert_eq(c.get_drain_failed(), 2, "failed count tracked")
	assert_eq(c.get_banner_stack().get_drain_entry()["severity"], ESM.Severity.WIPE,
		"AC-42: drain banner REPLACED by WIPE-weight persistent (never silent)")


# --- drain success → 全部儲好喇 ✓ → 2s auto-expire (EC-B8) ---

func test_drain_completed_all_saved_success_then_expires() -> void:
	var c := _make()
	c.request_logout()
	_client.drain_completed.emit(5, 0)  # all saved
	assert_eq(c.get_drain_state(), D_SUCCESS, "all saved → SUCCESS (全部儲好喇 ✓)")
	assert_false(c.get_banner_stack().get_drain_entry().is_empty(), "success banner present")
	# Advance the injected clock past DRAIN_SUCCESS_EXPIRE_SEC.
	c._clock_override_ms = CLOCK0 + int(ShellFormulas.DRAIN_SUCCESS_EXPIRE_SEC * 1000.0)
	c.advance(1.0)
	assert_eq(c.get_drain_state(), D_NONE, "success notice auto-expired")
	assert_true(c.get_banner_stack().get_drain_entry().is_empty(), "drain banner cleared after expire")


func test_drain_completed_zero_pending_still_shows_success() -> void:
	var c := _make()
	c.request_logout()
	_client.drain_completed.emit(0, 0)  # EC-B8 — nothing pending
	assert_eq(c.get_drain_state(), D_SUCCESS, "EC-B8: drain_completed(0,0) still shows 全部儲好喇 ✓")


# --- sequencing: SUCCESS notice cleared on LOGIN; PARTFAIL persists ---

func test_sequencing_success_notice_cleared_on_login_entry() -> void:
	var c := _make()
	c.request_logout()
	_client.drain_completed.emit(3, 0)  # SUCCESS notice up
	assert_false(c.get_banner_stack().get_drain_entry().is_empty(), "success notice present")
	# auth_required arrives → enter LOGIN.
	c._on_auth_required(null)
	for _i in range(8):
		c.advance(FADE)
	assert_true(c.get_banner_stack().get_drain_entry().is_empty(),
		"sequencing: 「可以安心熄 app」notice cleared on LOGIN entry (no contradiction with 請再登入)")


func test_sequencing_partfail_persists_through_login() -> void:
	var c := _make()
	c.request_logout()
	_client.drain_completed.emit(5, 2)  # PARTFAIL — honest, persists
	c._on_auth_required(null)
	for _i in range(8):
		c.advance(FADE)
	assert_false(c.get_banner_stack().get_drain_entry().is_empty(),
		"part-fail WIPE banner PERSISTS through re-login (honest — cleared on acknowledge)")
	assert_eq(c.get_banner_stack().get_drain_entry()["severity"], ESM.Severity.WIPE, "still WIPE-weight")
