extends GutTest
## Story 007 — Knob validation (release-safe, NOT raw assert). Covers AC-21a / AC-21b.
##
## GDD: Cross-knob invariants 1-2 + per-knob safe ranges. validate_knobs() returns
## a bool (Godot strips raw assert in release; GUT can't catch a raw assert failure —
## tautological phantom). Tests BOTH the pass path and the reject path.

const F := preload("res://src/ui/login_shell/shell_formulas.gd")


# --- AC-21a: valid default knobs pass ---

func test_ac21a_default_knobs_validate_true() -> void:
	assert_true(F.validate_knobs(), "AC-21a: default knobs pass")


func test_ac21a_explicit_defaults_validate_true() -> void:
	assert_true(
		F.validate_knobs(0.25, 5.0, 2.0, 0.10),
		"explicit default values pass")


# --- AC-21b: injected violations reject ---

func test_ac21b_drain_exceeds_transient_rejected() -> void:
	# a: DRAIN_SUCCESS=3.5 > TRANSIENT=3.0 → reject (range + invariant 1).
	assert_false(
		F.validate_knobs(0.25, 3.0, 3.5, 0.10),
		"AC-21b(a): DRAIN_SUCCESS 3.5 > TRANSIENT 3.0 → false")


func test_ac21b_banner_height_over_ceiling_rejected() -> void:
	# b: BANNER_MAX_HEIGHT_PCT=0.12 > 0.10 → reject (range + invariant 2).
	assert_false(
		F.validate_knobs(0.25, 5.0, 2.0, 0.12),
		"AC-21b(b): BANNER_MAX_HEIGHT_PCT 0.12 > 0.10 → false")


func test_drain_zero_rejected_f2_never_show_guard() -> void:
	# DRAIN_SUCCESS=0 violates the >0 lower bound (would make F2 never show — N4).
	assert_false(
		F.validate_knobs(0.25, 5.0, 0.0, 0.10),
		"DRAIN_SUCCESS=0 rejected (>0 lower bound)")


func test_shell_fade_out_of_range_rejected() -> void:
	assert_false(F.validate_knobs(0.05, 5.0, 2.0, 0.10), "SHELL_FADE 0.05 < 0.1 → false")
	assert_false(F.validate_knobs(0.6, 5.0, 2.0, 0.10), "SHELL_FADE 0.6 > 0.5 → false")


func test_transient_ttl_out_of_range_rejected() -> void:
	assert_false(F.validate_knobs(0.25, 2.0, 2.0, 0.10), "TRANSIENT 2.0 < 3.0 → false")
	assert_false(F.validate_knobs(0.25, 11.0, 2.0, 0.10), "TRANSIENT 11.0 > 10.0 → false")


# --- clamp helper (the「+ clamp」half of validate-then-clamp) ---

func test_clamp_knob_pins_to_range() -> void:
	assert_eq(F.clamp_knob(0.6, F.SHELL_FADE_MIN, F.SHELL_FADE_MAX), 0.5, "clamp high → max")
	assert_eq(F.clamp_knob(0.05, F.SHELL_FADE_MIN, F.SHELL_FADE_MAX), 0.1, "clamp low → min")
	assert_eq(F.clamp_knob(0.25, F.SHELL_FADE_MIN, F.SHELL_FADE_MAX), 0.25, "in range unchanged")
