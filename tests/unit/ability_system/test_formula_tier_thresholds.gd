# Unit tests — AbilitySystem Formula 1 tier thresholds (Story 005 / AC-21).
#
# TIER_THRESHOLDS = { TIER_1: 10, TIER_2: 50, TIER_3: 200 } with an INCLUSIVE `>=` boundary.
# These are boundary-value tests: the exact threshold numbers ARE the point (test-standards
# magic-number exception). Probes the boundaries 9/10 (T1), 49/50 (T2), 199/200 (T3) through
# the real _evaluate_unlock_tiers path so the >= semantics are verified end-to-end, not just as
# constant lookups.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

var _sut


func before_each() -> void:
	_sut = AbilitySystem.new()
	_sut._persistence = MockPersistenceLayer.new()
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


# --- Constant values (locked surface) ---------------------------------------------------------

func test_threshold_constants_locked() -> void:
	assert_eq(_sut.TIER_THRESHOLDS[_sut.AbilityTier.TIER_1], 10, "AC-21: TIER_1 threshold is 10")
	assert_eq(_sut.TIER_THRESHOLDS[_sut.AbilityTier.TIER_2], 50, "AC-21: TIER_2 threshold is 50")
	assert_eq(_sut.TIER_THRESHOLDS[_sut.AbilityTier.TIER_3], 200, "AC-21: TIER_3 threshold is 200")


# --- TIER_1 boundary: 9 (below) / 10 (exact) --------------------------------------------------

func test_tier_1_below_threshold_does_not_unlock() -> void:
	_sut._evaluate_unlock_tiers(&"str", 9.0, _sut.UnlockSource.STAT_THRESHOLD)
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-21: 9 is below the TIER_1 threshold (10) — no unlock")


func test_tier_1_exact_threshold_unlocks() -> void:
	_sut._evaluate_unlock_tiers(&"str", 10.0, _sut.UnlockSource.STAT_THRESHOLD)
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-21: 10 meets the TIER_1 threshold exactly (>= is inclusive) — unlock")


# --- TIER_2 boundary: 49 (below) / 50 (exact) -------------------------------------------------

func test_tier_2_below_threshold_does_not_unlock() -> void:
	_sut._evaluate_unlock_tiers(&"str", 49.0, _sut.UnlockSource.STAT_THRESHOLD)
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"],
		"AC-21: 49 is below the TIER_2 threshold (50) — T2 not unlocked")
	# (T1 IS unlocked at 49 — it cleared 10.)
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-21: 49 still clears T1 (10)")


func test_tier_2_exact_threshold_unlocks() -> void:
	_sut._evaluate_unlock_tiers(&"str", 50.0, _sut.UnlockSource.STAT_THRESHOLD)
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"],
		"AC-21: 50 meets the TIER_2 threshold exactly — unlock")


# --- TIER_3 boundary: 199 (below) / 200 (exact) -----------------------------------------------

func test_tier_3_below_threshold_does_not_unlock() -> void:
	_sut._evaluate_unlock_tiers(&"str", 199.0, _sut.UnlockSource.STAT_THRESHOLD)
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_3_OVERHAND)["unlocked"],
		"AC-21: 199 is below the TIER_3 threshold (200) — T3 not unlocked")


func test_tier_3_exact_threshold_unlocks() -> void:
	_sut._evaluate_unlock_tiers(&"str", 200.0, _sut.UnlockSource.STAT_THRESHOLD)
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_3_OVERHAND)["unlocked"],
		"AC-21: 200 meets the TIER_3 threshold exactly — unlock")
