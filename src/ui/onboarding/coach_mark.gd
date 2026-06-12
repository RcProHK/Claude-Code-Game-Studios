class_name OnboardingCoachMark
extends Control
## Peripheral, dismissible, non-blocking coach-mark card (#27, Rule 4 / coach-mark UX pattern).
## A small high-saturation HUD-class text card anchored to the periphery. Fade in/out is
## opacity-ONLY (no pulse, no gaze-drawing animation — #24 banner / P-17 restraint: teaching
## is a state, not an urgency gesture). NO BackBufferCopy / no blur (ADR-0001 #21/#24 ruling).
## mouse_filter = IGNORE everywhere so it NEVER steals the player's one-tap (UX-06). See
## design/ux/onboarding-flow.md + design/gdd/onboarding-flow.md Visual §.

const WARM_WHITE := Color("F5EFE0")  # HUD text palette (accessibility-requirements)
const AMBER := Color("F2A93B")
const INK := Color("1A1D24")

var _label: Label = null
var _fade_sec: float = 0.25
var _reduced_motion: bool = false


## Build the card. fade_sec 0 OR reduced_motion → hard cut (no animation; AC story 014).
func setup(text: String, fade_sec: float, reduced_motion: bool = false) -> void:
	_fade_sec = fade_sec
	_reduced_motion = reduced_motion
	# Peripheral anchor — top strip, never the central one-tap zone.
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("coach_text", text)

	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 1)
	add_child(panel)

	_label = Label.new()
	_label.name = "CoachText"
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", WARM_WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)

	_fade_in()


func get_text() -> String:
	return _label.text if _label != null else ""


func _fade_in() -> void:
	if _reduced_motion or _fade_sec <= 0.0 or not is_inside_tree():
		modulate.a = 1.0
		return
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, _fade_sec)


## Fade out then free (opacity-only). Reduced-motion / no-tree → immediate free.
func fade_out_and_free() -> void:
	if _reduced_motion or _fade_sec <= 0.0 or not is_inside_tree():
		queue_free()
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, _fade_sec)
	t.tween_callback(queue_free)
