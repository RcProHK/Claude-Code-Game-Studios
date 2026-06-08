extends GutTest
## Story 009 — LOGIN sub-variant dispatch (G-LS-4 mock-scoped). Covers AC-04
## (update_required → prompt, no form), AC-05 (carve_out_misconfig → operator prompt +
## acknowledge), and &"none" → normal form.
##
## GDD: Rule 2 + States LOGIN sub-variant. The reason is PULLED via get_auth_block_reason()
## on LOGIN entry (the forbidden-signal ban makes a getter the only legal channel).

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const V_NORMAL := CoordinatorScript.LoginVariant.NORMAL
const V_UPDATE := CoordinatorScript.LoginVariant.UPDATE_REQUIRED
const V_MISCONFIG := CoordinatorScript.LoginVariant.MISCONFIG
const S_LOGIN := CoordinatorScript.ShellState.LOGIN


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 0
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


class MockClient:
	extends Node
	var auth_required_value: bool = true
	var block_reason: StringName = &"none"
	var ack_calls: int = 0
	func is_auth_required() -> bool: return auth_required_value
	func get_auth_block_reason() -> StringName: return block_reason
	func acknowledge_carve_out_fix() -> void: ack_calls += 1


var _client: MockClient


func _make(reason: StringName) -> Node:
	var gsm := MockGsm.new()
	_client = MockClient.new()
	_client.block_reason = reason
	add_child_autofree(gsm)
	add_child_autofree(_client)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._client = _client
	add_child_autofree(c)  # boot pull-check enters LOGIN → refreshes the variant
	return c


# --- &"none" → normal form ---

func test_none_reason_is_normal_form() -> void:
	var c := _make(&"none")
	assert_eq(c.get_state(), S_LOGIN, "in LOGIN")
	assert_eq(c.get_login_variant(), V_NORMAL, "&\"none\" → NORMAL variant")
	assert_true(c.should_show_form(), "NORMAL shows the credential form")


# --- AC-04: update_required → prompt, NO form ---

func test_ac04_update_required_prompt_no_form() -> void:
	var c := _make(&"update_required")
	assert_eq(c.get_login_variant(), V_UPDATE, "AC-04: update_required variant")
	assert_false(c.should_show_form(), "AC-04: NO form behind the update prompt")


# --- AC-05: carve_out_misconfig → operator prompt + acknowledge ---

func test_ac05_misconfig_prompt_and_acknowledge() -> void:
	var c := _make(&"carve_out_misconfig")
	assert_eq(c.get_login_variant(), V_MISCONFIG, "AC-05: misconfig variant")
	assert_false(c.should_show_form(), "AC-05: operator prompt replaces the form")
	c.acknowledge_carve_out()
	assert_eq(_client.ack_calls, 1, "AC-05: acknowledge_carve_out_fix() invoked (#2 L149 hook)")


# --- pull-model: variant comes from the getter, not a signal ---

func test_variant_refreshes_from_getter_on_each_login_entry() -> void:
	var c := _make(&"update_required")
	assert_eq(c.get_login_variant(), V_UPDATE, "first entry → update_required")
	# Reason changes upstream; a fresh LOGIN entry re-pulls it.
	_client.block_reason = &"none"
	c.notify_claim_succeeded()  # leave LOGIN
	for _i in range(8):
		c.advance(CoordinatorScript.SHELL_FADE_MS)
	# Re-enter LOGIN.
	c._client.auth_required_value = true
	c._on_auth_required(null)
	for _i in range(8):
		c.advance(CoordinatorScript.SHELL_FADE_MS)
	assert_eq(c.get_login_variant(), V_NORMAL, "re-entry re-pulls the getter → NORMAL")
