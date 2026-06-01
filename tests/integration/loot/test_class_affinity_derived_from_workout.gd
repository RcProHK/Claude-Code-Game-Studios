# LootDropSystem — Story 014 AC-42: class_affinity_score[STRIKE] ≥ 0.65 from #9 WST.
#
# Coverage:
#   AC-42a — _get_dominant_class() returns AbilityClass.STRIKE when MockWST returns STRIKE.
#   AC-42b — class_affinity_resolution(WEAPON, STRIKE, rng_roll) returns ClassTag.STRIKE
#             for rng_roll ∈ [0.0, W_DOMINANT=0.65) — i.e. 65% of the probability mass.
#   AC-42c — Determinism: same dominant_class + same rng_roll → same ClassTag output across calls.
extends GutTest

const MOCK_WST := preload("res://tests/helpers/mock_workout_state_tracker.gd")

var _mock_wst: Object


func before_each() -> void:
	_mock_wst = MOCK_WST.new()
	_mock_wst.dominant_ability_class = AbilitySystem.AbilityClass.STRIKE
	LootDropSystem.set(&"_workout_tracker", _mock_wst)


func after_each() -> void:
	LootDropSystem.set(&"_workout_tracker", null)


# ---------------------------------------------------------------------------
# AC-42a — _get_dominant_class reflects injected MockWST
# ---------------------------------------------------------------------------

func test_ac42a_get_dominant_class_returns_strike_from_mock_wst() -> void:
	var dom = LootDropSystem.call("_get_dominant_class")
	assert_eq(dom, AbilitySystem.AbilityClass.STRIKE,
		"AC-42a: _get_dominant_class() must return AbilityClass.STRIKE when WST returns STRIKE")


func test_ac42a_get_dominant_class_returns_null_without_wst() -> void:
	LootDropSystem.set(&"_workout_tracker", null)
	var dom = LootDropSystem.call("_get_dominant_class")
	assert_null(dom, "AC-42a: _get_dominant_class() must return null when no WST injected (EC-35 fallback)")


# ---------------------------------------------------------------------------
# AC-42b — class_affinity probability mass ≥ 0.65 for STRIKE dominant
# ---------------------------------------------------------------------------

## Verify that for rng_roll_3 ∈ [0.0, 0.65), class_affinity_resolution returns STRIKE.
## This directly tests the W_DOMINANT=0.65 contract (CF-E2) from LootItemCalc.
func test_ac42b_strike_dominant_returns_strike_for_rolls_below_w_dominant() -> void:
	const SAMPLES := 100
	var strike_count: int = 0
	for i in SAMPLES:
		var rng_roll: float = float(i) / float(SAMPLES)
		var result: int = LootItemCalc.class_affinity_resolution(
			LootEnums.ItemType.WEAPON,
			AbilitySystem.AbilityClass.STRIKE,
			rng_roll
		)
		if result == LootEnums.ClassTag.STRIKE:
			strike_count += 1
	# W_DOMINANT = 0.65 → rolls [0.00, 0.65) = 65 out of 100 samples = STRIKE.
	assert_gte(float(strike_count) / float(SAMPLES), 0.65,
		"AC-42b: STRIKE dominant must produce ClassTag.STRIKE for ≥ 65% of uniform rng_roll samples (W_DOMINANT=0.65)")


## Spot-check: rng_roll=0.0 must always → STRIKE with STRIKE dominant.
func test_ac42b_rng_roll_zero_is_always_strike() -> void:
	var result: int = LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, AbilitySystem.AbilityClass.STRIKE, 0.0)
	assert_eq(result, LootEnums.ClassTag.STRIKE,
		"AC-42b: rng_roll=0.0 with STRIKE dominant must return ClassTag.STRIKE (start of CDF band)")


## Spot-check: rng_roll=0.64 must → STRIKE (still within W_DOMINANT band).
func test_ac42b_rng_roll_0_64_is_strike() -> void:
	var result: int = LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, AbilitySystem.AbilityClass.STRIKE, 0.64)
	assert_eq(result, LootEnums.ClassTag.STRIKE,
		"AC-42b: rng_roll=0.64 with STRIKE dominant must return ClassTag.STRIKE (within 0.65 band)")


# ---------------------------------------------------------------------------
# AC-42c — determinism
# ---------------------------------------------------------------------------

func test_ac42c_same_inputs_always_same_output() -> void:
	const ROLL: float = 0.30
	var a: int = LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, AbilitySystem.AbilityClass.STRIKE, ROLL)
	var b: int = LootItemCalc.class_affinity_resolution(
		LootEnums.ItemType.WEAPON, AbilitySystem.AbilityClass.STRIKE, ROLL)
	assert_eq(a, b, "AC-42c: class_affinity_resolution must be deterministic for fixed inputs")
	assert_eq(a, LootEnums.ClassTag.STRIKE, "AC-42c: rng_roll=0.30 with STRIKE dominant → STRIKE")
