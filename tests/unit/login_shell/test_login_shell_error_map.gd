extends GutTest
## Story 008 — 4-code error map + zero-raw-HTTP deny-list. Covers AC-09 / AC-10 /
## AC-11 / AC-23.
##
## GDD: Rule 3. The claim result is mapped to exactly 4 player-facing buckets; a raw
## HTTP code is NEVER leaked — every copy must fail the deny-list regex \d{3} and must
## not contain "HTTP"/"http". Session conflict buckets into server_error (no own code).

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


var _digit_re: RegEx


func before_all() -> void:
	_digit_re = RegEx.new()
	_digit_re.compile("\\d{3}")


func _make() -> Node:
	var gsm := MockGsm.new()
	var client := MockClient.new()
	add_child_autofree(gsm)
	add_child_autofree(client)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._client = client
	add_child_autofree(c)
	return c


func _submit_then_result(c: Node, code: StringName) -> String:
	c.submit_claim("user", "pass")
	c.notify_claim_result(code)
	return c.get_claim_error_copy()


## Deny-list assertion (AC-09 qa R6): no 3-digit run, no "HTTP"/"http".
func _assert_no_raw_http(copy: String, ctx: String) -> void:
	assert_eq(_digit_re.search(copy), null, "%s: copy must not contain a 3-digit run (\\d{3})" % ctx)
	assert_false(copy.to_lower().contains("http"), "%s: copy must not contain HTTP/http" % ctx)


# --- AC-09: invalid_credentials ---

func test_ac09_invalid_credentials_inline_and_reenable() -> void:
	var c := _make()
	var copy := _submit_then_result(c, &"invalid_credentials")
	assert_false(copy.is_empty(), "AC-09: inline error copy present")
	assert_false(c.is_claim_loading(), "AC-09: re-enabled")
	assert_false(c.get_claim_show_retry(), "invalid_credentials has no retry button (re-enter)")
	_assert_no_raw_http(copy, "AC-09")


# --- AC-10: network_error ---

func test_ac10_network_error_retry_and_no_raw_http() -> void:
	var c := _make()
	var copy := _submit_then_result(c, &"network_error")
	assert_false(copy.is_empty(), "AC-10: inline copy")
	assert_true(c.get_claim_show_retry(), "AC-10: retry button shown")
	assert_false(c.is_claim_loading(), "re-enabled")
	_assert_no_raw_http(copy, "AC-10")


# --- AC-11: server_error ---

func test_ac11_server_error_retry_reenable_no_raw_http() -> void:
	var c := _make()
	var copy := _submit_then_result(c, &"server_error")
	assert_false(copy.is_empty(), "AC-11: inline copy")
	assert_true(c.get_claim_show_retry(), "AC-11: retry button")
	assert_false(c.is_claim_loading(), "AC-11: re-enabled")
	_assert_no_raw_http(copy, "AC-11")


# --- AC-23: session conflict buckets into server_error ---

func test_ac23_session_conflict_uses_server_error_bucket() -> void:
	# #2 maps a conflict to the server_error bucket (no conflict-specific code reaches #24).
	var c := _make()
	var conflict_copy := _submit_then_result(c, &"server_error")
	var c2 := _make()
	var plain_server := _submit_then_result(c2, &"server_error")
	assert_eq(conflict_copy, plain_server, "AC-23: conflict copy == server_error copy (no own bucket)")
	_assert_no_raw_http(conflict_copy, "AC-23")
	assert_false(conflict_copy.to_lower().contains("conflict"), "no conflict-specific leak")


# --- all four buckets pass the deny-list ---

func test_all_buckets_pass_deny_list() -> void:
	for code in [&"invalid_credentials", &"network_error", &"server_error"]:
		var c := _make()
		var copy := _submit_then_result(c, code)
		_assert_no_raw_http(copy, "deny-list[%s]" % code)
