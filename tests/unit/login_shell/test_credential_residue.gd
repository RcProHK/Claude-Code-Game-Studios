## Story 015 AC-50 — credential residue: the password field is wiped after a claim/login
## resolves; on failure the username is kept for re-entry (EC-A3). (The static grep half of
## AC-50 — zero credential vars into print/push_error — is story 016's CI step.)
extends GutTest

const FORM := preload("res://src/ui/login_shell/login_form.gd")

var _f: Control


func before_each() -> void:
	_f = FORM.new()
	add_child_autofree(_f)
	await get_tree().process_frame


func _u() -> LineEdit: return _f.find_child("Username", true, false)
func _p() -> LineEdit: return _f.find_child("Password", true, false)


func test_clear_password_wipes_password_keeps_username() -> void:
	_u().text = "alice"
	_p().text = "secret"
	_f.clear_password()
	assert_eq(_p().text, "", "AC-50: password wiped after resolve")
	assert_eq(_u().text, "alice", "EC-A3: username preserved for re-entry")


func test_clear_credentials_wipes_both() -> void:
	_u().text = "alice"
	_p().text = "secret"
	_f.clear_credentials()
	assert_eq(_u().text, "", "both cleared")
	assert_eq(_p().text, "", "both cleared")


func test_toggle_reveals_and_hides_password() -> void:
	var p := _p()
	var t: Button = _f.find_child("PasswordToggle", true, false)
	assert_true(p.secret, "secret by default")
	t.button_pressed = true
	t.pressed.emit()
	assert_false(p.secret, "toggle ON reveals")
	t.button_pressed = false
	t.pressed.emit()
	assert_true(p.secret, "toggle OFF hides")
