## LoginForm — #24 story 015: the LOGIN credential form (LZ-Form).
##
## username + password(secret) + show-password toggle(👁 ≥44px) + submit「登入」(amber) +
## inline error area. NO remember-me / register / forgot-password (AC-12 — GymSys account
## management lives in GymSys itself; token persist is the default 30-day TTL).
##
## Emits `submitted(username, password)` on submit → LoginShellCoordinator.submit_login().
## Credential residue (AC-50): clear_password() wipes the password field after a claim/login
## resolves; on invalid_credentials the coordinator keeps username + clears password.
##
## MVP canvas LineEdit (no browser password-manager / Keychain autofill — DOM-overlay is the
## v0.2 route gated by story 001 G-LS-6 spike). UX: design/ux/login-gymsys-connection-ui.md (LZ-Form).
extends Control

signal submitted(username: String, password: String)

const AMBER := Color(0.949, 0.663, 0.231)     ## event_amber #F2A93B — submit is the only amber
const INK := Color(0.102, 0.114, 0.141)        ## ui_ink for label-on-amber
const FIELD_BG := Color(0.13, 0.15, 0.18)      ## input bg (ink −10%)
const TAP_MIN := 44.0                          ## ≥44px tap target / field height
const FONT_MIN := 16                           ## ≥16px input font

var _username: LineEdit
var _password: LineEdit
var _toggle: Button
var _submit: Button
var _error: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := VBoxContainer.new()
	card.name = "FormCard"
	card.add_theme_constant_override("separation", 12)
	card.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 32.0, 360.0), 0)
	center.add_child(card)

	var title := Label.new()
	title.name = "Title"
	title.text = "MIRROR HERO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	card.add_child(title)

	_username = _make_field("Username", "Username", false)
	card.add_child(_username)

	var pw_row := HBoxContainer.new()
	pw_row.name = "PasswordRow"
	pw_row.add_theme_constant_override("separation", 8)
	card.add_child(pw_row)
	_password = _make_field("Password", "Password", true)
	_password.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw_row.add_child(_password)
	_toggle = Button.new()
	_toggle.name = "PasswordToggle"
	_toggle.text = "👁"
	_toggle.toggle_mode = true
	_toggle.custom_minimum_size = Vector2(TAP_MIN, TAP_MIN)
	_toggle.tooltip_text = "顯示/收埋密碼"
	_toggle.pressed.connect(_on_toggle)
	pw_row.add_child(_toggle)

	_error = Label.new()
	_error.name = "InlineError"
	_error.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))  # zero red
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	card.add_child(_error)

	_submit = Button.new()
	_submit.name = "Submit"
	_submit.text = "登入"
	_submit.custom_minimum_size = Vector2(0, TAP_MIN)
	var sb := StyleBoxFlat.new()
	sb.bg_color = AMBER
	sb.set_corner_radius_all(4)
	_submit.add_theme_stylebox_override("normal", sb)
	_submit.add_theme_color_override("font_color", INK)
	_submit.pressed.connect(_on_submit)
	card.add_child(_submit)

	# Tab order = tree order: username → password → toggle → submit (UX LZ-Form).
	_username.grab_focus()


func _make_field(node_name: String, placeholder: String, secret: bool) -> LineEdit:
	var le := LineEdit.new()
	le.name = node_name
	le.placeholder_text = placeholder
	le.secret = secret                              # password hidden by default
	le.custom_minimum_size = Vector2(0, TAP_MIN)
	le.add_theme_font_size_override("font_size", FONT_MIN)
	var sb := StyleBoxFlat.new()
	sb.bg_color = FIELD_BG
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	le.add_theme_stylebox_override("normal", sb)
	return le


func _on_toggle() -> void:
	_password.secret = not _toggle.button_pressed    # pressed = showing


func _on_submit() -> void:
	submitted.emit(_username.text, _password.text)


# ── Credential residue (AC-50) — coordinator calls these after a claim/login resolves ──
func clear_password() -> void:
	_password.text = ""

func clear_credentials() -> void:
	_username.text = ""
	_password.text = ""

func show_error(copy: String) -> void:
	_error.text = copy
	_error.visible = not copy.is_empty()
