## Story 015 AC-12 — LoginForm (LZ-Form) element spec.
## form renders username + password(secret) + show-password toggle + submit; and does NOT
## render remember-me / register / forgot-password (GymSys account mgmt lives in GymSys).
extends GutTest

const FORM := preload("res://src/ui/login_shell/login_form.gd")

var _f: Control


func before_each() -> void:
	_f = FORM.new()
	add_child_autofree(_f)
	await get_tree().process_frame   # _ready() builds the UI


func test_has_username_password_toggle_submit() -> void:
	var fields: Array[Node] = _f.find_children("*", "LineEdit", true, false)
	assert_eq(fields.size(), 2, "AC-12: exactly username + password LineEdits")
	var secret_count := 0
	for le: LineEdit in fields:
		if le.secret:
			secret_count += 1
	assert_eq(secret_count, 1, "AC-12: exactly one secret field (the password)")
	assert_not_null(_f.find_child("Username", true, false), "AC-12: username present")
	assert_not_null(_f.find_child("Password", true, false), "AC-12: password present")
	assert_not_null(_f.find_child("PasswordToggle", true, false), "AC-12: show-password toggle present")
	assert_not_null(_f.find_child("Submit", true, false), "AC-12: submit present")


func test_no_remember_register_forgot_elements() -> void:
	for bad: String in ["*remember*", "*register*", "*forgot*", "*註冊*", "*忘記*", "*記住*"]:
		assert_eq(_f.find_children(bad, "", true, false).size(), 0,
			"AC-12: anti-scope element '%s' must NOT exist" % bad)


func test_password_secret_by_default() -> void:
	var p: LineEdit = _f.find_child("Password", true, false)
	assert_true(p.secret, "AC-12: password hidden by default")


func test_tap_targets_at_least_44px() -> void:
	for n: String in ["Username", "Password", "PasswordToggle", "Submit"]:
		var c: Control = _f.find_child(n, true, false)
		assert_true(c.custom_minimum_size.y >= 44.0, "%s tap target ≥44px" % n)


func test_submit_emits_credentials() -> void:
	watch_signals(_f)
	(_f.find_child("Username", true, false) as LineEdit).text = "alice"
	(_f.find_child("Password", true, false) as LineEdit).text = "pass1234"
	(_f.find_child("Submit", true, false) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(_f, "submitted", ["alice", "pass1234"])
