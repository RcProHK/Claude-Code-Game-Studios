extends GutTest
## Story 009: CombatVisualFeedback (#25) Formula 1 — damage number rise+fade (AC-20).
## Pure static lookups; deterministic; ratio clamped [0,1] for robustness.

const F := preload("res://src/core/combat_visual_feedback_formulas.gd")


# Default knobs (RISE_PX=40, LIFETIME=0.8, FADE_START=0.5).

func test_y_offset_midpoint_is_minus_30() -> void:
	# t=0.4 → ratio 0.5 → ease_out(0.5)=0.75 → -40 × 0.75 = -30
	assert_almost_eq(F.number_y_offset(0.4), -30.0, 0.001, "AC-20: y_offset(0.4) ≈ -30")


func test_y_offset_end_is_full_rise() -> void:
	assert_almost_eq(F.number_y_offset(0.8), -40.0, 0.001, "AC-20: y_offset(LIFETIME) = -RISE_PX = -40")


func test_y_offset_start_is_zero() -> void:
	assert_almost_eq(F.number_y_offset(0.0), 0.0, 0.001, "AC-20: y_offset(0) = 0")


func test_alpha_full_at_fade_start() -> void:
	# t=0.4 → ratio 0.5 == FADE_START → smoothstep(0.5,1,0.5)=0 → alpha=1.0
	assert_almost_eq(F.number_alpha(0.4), 1.0, 0.001, "AC-20: alpha(0.4) = 1.0 (fade just begins)")


func test_alpha_zero_at_end() -> void:
	assert_almost_eq(F.number_alpha(0.8), 0.0, 0.001, "AC-20: alpha(LIFETIME) = 0")


func test_alpha_start_is_one() -> void:
	assert_almost_eq(F.number_alpha(0.0), 1.0, 0.001, "AC-20: alpha(0) = 1.0")


## Robustness: a t past LIFETIME (possible after a MAX_FRAME_DELTA clamp) must clamp,
## never flip ease_out positive or alpha negative.
func test_overshoot_ratio_is_clamped_monotone() -> void:
	assert_almost_eq(F.number_y_offset(2.0), -40.0, 0.001, "robustness: y_offset clamps at -RISE_PX (not positive)")
	assert_almost_eq(F.number_alpha(2.0), 0.0, 0.001, "robustness: alpha clamps at 0 (not negative)")


## Monotonic rise across the lifetime (no reversal).
func test_y_offset_monotone_rising() -> void:
	var prev := 0.0
	for i in range(1, 9):
		var t := i * 0.1
		var y := F.number_y_offset(t)
		assert_lte(y, prev + 0.0001, "y_offset must be monotone non-increasing at t=%f" % t)
		prev = y
