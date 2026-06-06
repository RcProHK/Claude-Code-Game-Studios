extends GutTest
## Story 001 — PRDeltaCalc + Formula 1 goldens.
## Covers #18 AC-11 / AC-12 / AC-13 (compute half) / AC-05 (formula half).
## All vectors are GDD-pinned goldens (qa-verified) — do not invent new ones.


# --- AC-11: Formula 1 goldens -------------------------------------------------

func test_e1rm_golden_60x5_is_70() -> void:
	assert_almost_eq(PRDeltaCalc.e1rm(60.0, 5), 70.0, 0.001)


func test_e1rm_golden_65x3_is_71_5() -> void:
	assert_almost_eq(PRDeltaCalc.e1rm(65.0, 3), 71.5, 0.001)


func test_e1rm_reps_1_goes_through_epley_no_special_case() -> void:
	# 100 × (1 + 1/30) ≈ 103.333 — NOT 100 (same ruler, no special case).
	assert_almost_eq(PRDeltaCalc.e1rm(100.0, 1), 103.333, 0.001)


func test_e1rm_rep_clamp_100x15_is_140() -> void:
	# D7 clamp: effective_reps = min(15, 12) → 100 × 1.4 = 140.
	assert_almost_eq(PRDeltaCalc.e1rm(100.0, 15), 140.0, 0.001)


# --- AC-05 (formula half): rep clamp semantics --------------------------------

func test_e1rm_rep_only_growth_past_cap_is_flat() -> void:
	# Same weight 12 vs 15 reps → identical e1rm (rep-only growth past 12 never PRs).
	assert_almost_eq(PRDeltaCalc.e1rm(100.0, 12), PRDeltaCalc.e1rm(100.0, 15), 0.000001)


func test_e1rm_added_weight_at_high_reps_still_moves() -> void:
	# 110 × 1.4 = 154 (clamp 後加重照升 — m = 0.1 against the 140 baseline).
	assert_almost_eq(PRDeltaCalc.e1rm(110.0, 15), 154.0, 0.001)


# --- AC-12: compute golden (#11 L338-340 worked example) -----------------------

func test_compute_golden_stat12_m0833_is_0500() -> void:
	# 6.0 × 0.0833 × (1 − (12/999)²) ≈ 0.500 — pinned on PROVISIONAL PR_BASE=6.0
	# (ADR-0005 retune updates this test).
	assert_almost_eq(PRDeltaCalc.compute(12.0, 0.0833), 0.500, 0.001)


# --- AC-13 (compute half): hard cap exact zero ---------------------------------

func test_compute_at_cap_999_is_exact_zero_for_sample_set() -> void:
	for m: float in [0.01, 0.5, 2.0]:
		assert_eq(PRDeltaCalc.compute(999.0, m), 0.0,
			"capped stat must yield EXACT 0.0 (Rule 6.3 short-circuit relies on it), m=%s" % m)


# --- Guard: int-division trap ---------------------------------------------------

func test_e1rm_divisor_is_float_no_int_division_trap() -> void:
	# If E1RM_DIVISOR were int, 5/30 == 0 → e1rm == weight. 70 ≠ 60 proves float path.
	assert_true(PRDeltaCalc.e1rm(60.0, 5) > 60.0)
