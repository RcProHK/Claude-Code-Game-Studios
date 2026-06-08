extends GutTest
## Story 008 — claim edge cases: rate_limited → Formula 1 countdown dispatch, unknown
## result code default-deny, and ghost-result safety.
##
## GDD: Rule 3/4 / EC-A4. rate_limited hands off to Formula 1 (story 006); an unknown
## code is surfaced (never silently swallowed) without leaking the raw value.

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 0
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		callable.call(current_state, current_state, null)


class MockClient:
	extends Node
	var auth_required_value: bool = true
	func is_auth_required() -> bool: return auth_required_value
	func claim_session(_u: String, _p: String) -> void: pass


func _make() -> Node:
	var gsm := MockGsm.new()
	var client := MockClient.new()
	add_child_autofree(gsm)
	add_child_autofree(client)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._client = client
	c._clock_override_ms = 100000  # deterministic banner/claim clock
	add_child_autofree(c)
	return c


# --- rate_limited → Formula 1 countdown dispatch (story 006) ---

func test_rate_limited_dispatches_to_formula1_countdown() -> void:
	var c := _make()
	c.submit_claim("user", "pass")
	c.notify_claim_result(&"rate_limited", 30)  # retry_after = 30s, t_start = 100000ms
	# Immediately after, the full 30s remain.
	assert_eq(c.get_rate_limit_seconds(), 30, "rate_limited → Formula 1 countdown seeded (30s)")
	# Advance the injected clock 15s.
	c._clock_override_ms = 115000
	assert_eq(c.get_rate_limit_seconds(), 15, "countdown ticks via injected clock (15s left)")
	c._clock_override_ms = 130000
	assert_eq(c.get_rate_limit_seconds(), 0, "countdown reaches 0 at retry_after boundary")


func test_no_rate_limit_seconds_when_not_rate_limited() -> void:
	var c := _make()
	c.submit_claim("user", "pass")
	c.notify_claim_result(&"server_error")
	assert_eq(c.get_rate_limit_seconds(), 0, "non-rate-limited result → no countdown")


# --- unknown result code → default-deny (surfaced, never silent / never raw) ---

func test_unknown_code_default_deny_surfaces_copy() -> void:
	var c := _make()
	c.submit_claim("user", "pass")
	c.notify_claim_result(&"some_future_code_999")
	var copy: String = c.get_claim_error_copy()
	assert_false(copy.is_empty(), "unknown code is surfaced, never silently swallowed")
	assert_false(copy.contains("some_future_code_999"), "raw code value not leaked")
	assert_false(c.is_claim_loading(), "re-enabled")


# --- result without a pending claim is a no-op (defensive) ---

func test_result_without_pending_claim_is_noop() -> void:
	var c := _make()
	c.notify_claim_result(&"success")  # no submit first
	assert_false(c.is_claim_loading(), "no spurious loading")
	assert_eq(c.get_claim_session_calls(), 0, "no claim was ever submitted")
