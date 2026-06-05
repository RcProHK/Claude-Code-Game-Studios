# BossFormulas Formula 4 — reveal_ritual_intensity_scaling (Story 006: AC-21 / AC-24 / CF-5 / CI-4).
# Pure static clamp.
extends GutTest


# ---------------------------------------------------------------------------
# AC-21 — clamp behaviour
# ---------------------------------------------------------------------------

func test_ac21_valid_value_passes_through() -> void:
	assert_eq(BossFormulas.compute_ritual_intensity(0.6), 0.6, "AC-21: 0.6 -> 0.6 (within range)")
	assert_eq(BossFormulas.compute_ritual_intensity(1.0), 1.0, "AC-21: 1.0 -> 1.0 (default final)")


func test_ac21_above_ceiling_clamps_to_max() -> void:
	assert_eq(BossFormulas.compute_ritual_intensity(1.5), BossFormulas.MAX_RITUAL_INTENSITY,
		"AC-21: invalid 1.5 -> clamped to MAX_RITUAL_INTENSITY (1.0)")


func test_below_floor_clamps_to_min() -> void:
	assert_eq(BossFormulas.compute_ritual_intensity(0.3), BossFormulas.MIN_RITUAL_INTENSITY,
		"below MIN -> clamped up to MIN_RITUAL_INTENSITY")


# ---------------------------------------------------------------------------
# CF-5 / CI-4 — ceiling invariants
# ---------------------------------------------------------------------------

func test_cf5_output_never_exceeds_max() -> void:
	for v in [-1.0, 0.0, 0.5, 1.0, 1.4, 5.0]:
		assert_true(BossFormulas.compute_ritual_intensity(v) <= BossFormulas.MAX_RITUAL_INTENSITY,
			"CF-5: ritual_caller_mult <= MAX_RITUAL_INTENSITY for input %s" % str(v))


func test_ci4_max_below_particle_ceiling() -> void:
	# CI-4: MAX_RITUAL_INTENSITY must stay below #5 max_caller_multiplier = 1.5.
	assert_true(BossFormulas.MAX_RITUAL_INTENSITY <= 1.5,
		"CI-4: MAX_RITUAL_INTENSITY (1.0) <= #5 max_caller_multiplier (1.5)")


func test_ac24_final_default_within_ceiling() -> void:
	# A final boss template's default reveal_ritual_intensity (1.0) yields <= 1.0.
	assert_true(BossFormulas.compute_ritual_intensity(1.0) <= 1.0,
		"AC-24: final default reveal intensity stays <= 1.0 (well below #5's 1.5)")
