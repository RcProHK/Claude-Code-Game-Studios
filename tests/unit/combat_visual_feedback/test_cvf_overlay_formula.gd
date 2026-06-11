extends GutTest
## Story 010: CombatVisualFeedback (#25) Formula 2 — overlay flash alpha decay (AC-21).
## Pure static; linear decay from peak opacity to 0; clamps non-negative.

const F := preload("res://src/core/combat_visual_feedback_formulas.gd")


func test_overkill_halfway_is_030() -> void:
	# OVERKILL: MAX_OPACITY=0.6, DURATION=0.12, t=0.06 → 0.6 × 0.5 = 0.30
	assert_almost_eq(F.overlay_alpha(0.06, 0.6, 0.12), 0.30, 0.0001, "AC-21: overlay_alpha(0.06) = 0.30")


func test_at_duration_is_zero() -> void:
	assert_almost_eq(F.overlay_alpha(0.12, 0.6, 0.12), 0.0, 0.0001, "AC-21: alpha at duration = 0")


func test_at_start_is_peak() -> void:
	assert_almost_eq(F.overlay_alpha(0.0, 0.6, 0.12), 0.6, 0.0001, "AC-21: alpha(0) = peak opacity")


func test_past_duration_clamps_zero() -> void:
	assert_almost_eq(F.overlay_alpha(0.2, 0.6, 0.12), 0.0, 0.0001, "robustness: alpha never negative past duration")


func test_critical_peak_is_035() -> void:
	assert_almost_eq(F.overlay_alpha(0.0, F.OVERLAY_MAX_OPACITY_CRITICAL, F.CRITICAL_FLASH_DURATION_SEC),
		0.35, 0.0001, "CRITICAL flash peak = 0.35")


func test_zero_duration_safe() -> void:
	assert_almost_eq(F.overlay_alpha(0.0, 0.6, 0.0), 0.0, 0.0001, "division-by-zero guard → 0")
