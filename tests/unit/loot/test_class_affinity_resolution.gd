## test_class_affinity_resolution.gd — Story 007 AC-16
##
## Governing story: production/epics/loot-drop-system/story-007-formula-e1-e2-e4.md
## Governing ADRs : ADR-0007 F-7 (ClassTag ≠ AbilityClass); ADR-0005 CI-6 (deterministic RNG)
##
## AC-16: class_affinity_resolution() must produce the GDD worked example (NEUTRAL
## at rng_roll_3=0.78 with WEAPON + dominant=STRIKE), handle CONSUMABLE/COSMETIC
## early-return to NEUTRAL, and EC-35 uniform fallback when dominant_class is null.
##
## GDD CDF order (§D Formula E2 worked example):
##   dominant(0.65) → NEUTRAL(0.20) → off-class1(0.075) → off-class2(0.075)
##   With STRIKE dominant: STRIKE=0.650, NEUTRAL=0.850, CONTROL=0.925, MOBILITY=1.000
##   0.78 ∈ [0.650, 0.850) → NEUTRAL ✓
extends GutTest


# ── AC-16: GDD worked example ─────────────────────────────────────────────────

func test_ac16_gdd_worked_example_weapon_strike_roll_078_returns_neutral() -> void:
	# GDD AC-16 canonical: WEAPON, dominant=STRIKE, rng_roll_3=0.78 → NEUTRAL.
	# CDF order (GDD §D Formula E2): dominant → NEUTRAL → off-classes.
	# With STRIKE dominant: STRIKE CDF=0.650, NEUTRAL CDF=0.850; 0.78 → NEUTRAL.
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, LootEnums.ClassTag.STRIKE, 0.78
	)
	assert_eq(result, LootEnums.ClassTag.NEUTRAL,
		"AC-16: WEAPON + STRIKE dominant + rng_roll_3=0.78 must return NEUTRAL (GDD worked example)")


func test_ac16_cf_e2_weights_sum_to_one() -> void:
	# CF-E2: W_DOMINANT + W_NEUTRAL + 2×W_OFF_CLASS = 0.65 + 0.20 + 0.075 + 0.075 = 1.00
	var sum := LootItemCalc.W_DOMINANT + LootItemCalc.W_NEUTRAL + 2.0 * LootItemCalc.W_OFF_CLASS
	assert_almost_eq(sum, 1.0, 1e-6,
		"CF-E2: W_DOMINANT + W_NEUTRAL + 2×W_OFF_CLASS must sum to 1.0")


func test_ac16_same_inputs_same_result_deterministic() -> void:
	# Determinism: same inputs → same output every time (CI-6 Pillar 1 replay).
	var r1 := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, LootEnums.ClassTag.CONTROL, 0.50
	)
	var r2 := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, LootEnums.ClassTag.CONTROL, 0.50
	)
	assert_eq(r1, r2, "Same inputs must always produce the same ClassTag (CI-6 determinism)")


# ── CONSUMABLE / COSMETIC → always NEUTRAL ─────────────────────────────────────

func test_consumable_always_neutral_regardless_of_dominant() -> void:
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.CONSUMABLE, LootEnums.ClassTag.STRIKE, 0.99
	)
	assert_eq(result, LootEnums.ClassTag.NEUTRAL,
		"CONSUMABLE must always return NEUTRAL (no class affinity)")


func test_cosmetic_always_neutral_regardless_of_roll() -> void:
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.COSMETIC, LootEnums.ClassTag.CONTROL, 0.0
	)
	assert_eq(result, LootEnums.ClassTag.NEUTRAL,
		"COSMETIC must always return NEUTRAL (no class affinity)")


func test_consumable_neutral_even_with_null_dominant() -> void:
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.CONSUMABLE, null, 0.50
	)
	assert_eq(result, LootEnums.ClassTag.NEUTRAL,
		"CONSUMABLE with null dominant_class must still return NEUTRAL")


# ── EC-35: null dominant_class → uniform fallback ─────────────────────────────

func test_ec35_null_dominant_roll_0_returns_strike() -> void:
	# Uniform: idx = int(0.0 * 4) = 0 → STRIKE (first in UNIFORM_ORDER).
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, null, 0.0
	)
	assert_eq(result, LootEnums.ClassTag.STRIKE,
		"EC-35: null dominant + rng_roll_3=0.0 must return STRIKE (idx=0 in uniform order)")


func test_ec35_null_dominant_roll_025_returns_control() -> void:
	# idx = int(0.25 * 4) = 1 → CONTROL.
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.ARMOR, null, 0.25
	)
	assert_eq(result, LootEnums.ClassTag.CONTROL,
		"EC-35: null dominant + rng_roll_3=0.25 must return CONTROL (idx=1 in uniform order)")


func test_ec35_null_dominant_roll_075_returns_neutral() -> void:
	# idx = int(0.75 * 4) = 3 → NEUTRAL (4th in [STRIKE, CONTROL, MOBILITY, NEUTRAL]).
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, null, 0.75
	)
	assert_eq(result, LootEnums.ClassTag.NEUTRAL,
		"EC-35: null dominant + rng_roll_3=0.75 must return NEUTRAL (idx=3 in uniform order)")


# ── Dominant class biasing ────────────────────────────────────────────────────

func test_dominant_strike_low_roll_returns_strike() -> void:
	# With STRIKE dominant (W=0.65), rng_roll_3=0.30 < 0.65 must land on STRIKE.
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, LootEnums.ClassTag.STRIKE, 0.30
	)
	assert_eq(result, LootEnums.ClassTag.STRIKE,
		"0.30 < W_DOMINANT=0.65 must return STRIKE (dominant class is first in CDF)")


func test_dominant_control_low_roll_returns_control() -> void:
	# CONTROL dominant, roll=0.30 < 0.65 → CONTROL.
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.ARMOR, LootEnums.ClassTag.CONTROL, 0.30
	)
	assert_eq(result, LootEnums.ClassTag.CONTROL,
		"0.30 < W_DOMINANT=0.65 must return CONTROL (dominant class is first in CDF)")


func test_dominant_strike_roll_in_neutral_band_returns_neutral() -> void:
	# STRIKE dominant CDF: STRIKE=0.65, NEUTRAL=0.85; 0.70 ∈ [0.65, 0.85) → NEUTRAL.
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, LootEnums.ClassTag.STRIKE, 0.70
	)
	assert_eq(result, LootEnums.ClassTag.NEUTRAL,
		"0.70 ∈ [0.65, 0.85) with STRIKE dominant must return NEUTRAL")


func test_dominant_strike_roll_past_neutral_returns_off_class() -> void:
	# STRIKE dominant CDF: STRIKE=0.65, NEUTRAL=0.85, CONTROL=0.925, MOBILITY=1.0.
	# 0.90 ∈ [0.85, 0.925) → CONTROL (first off-class in iteration).
	var result := LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, LootEnums.ClassTag.STRIKE, 0.90
	)
	# Off-class (CONTROL or MOBILITY — depends on off_classes Array order which is
	# determined by the loop [STRIKE,CONTROL,MOBILITY] minus dom=STRIKE → [CONTROL,MOBILITY]).
	# 0.90 ∈ [0.85, 0.925) → CONTROL.
	assert_eq(result, LootEnums.ClassTag.CONTROL,
		"0.90 with STRIKE dominant (past NEUTRAL band) must return CONTROL (first off-class)")
