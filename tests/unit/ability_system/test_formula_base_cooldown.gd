# Unit tests — AbilitySystem Formula 2 base cooldown per tier (Story 006 / AC-22).
#
# BASE_COOLDOWN_SEC = { TIER_1: 3.0, TIER_2: 6.0, TIER_3: 10.0 } — higher tiers cool down slower.
# Also covers _get_ability_tier (id → tier resolution) since the cooldown formula is keyed on it.
# The exact second values ARE the contract (test-standards magic-number exception).
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

var _sut


func before_each() -> void:
	_sut = AbilitySystem.new()


func after_each() -> void:
	_sut.free()
	_sut = null


# --- Constant values (locked surface) ---------------------------------------------------------

func test_base_cooldown_constants_locked() -> void:
	assert_eq(_sut.BASE_COOLDOWN_SEC[_sut.AbilityTier.TIER_1], 3.0, "AC-22: TIER_1 base cooldown is 3.0s")
	assert_eq(_sut.BASE_COOLDOWN_SEC[_sut.AbilityTier.TIER_2], 6.0, "AC-22: TIER_2 base cooldown is 6.0s")
	assert_eq(_sut.BASE_COOLDOWN_SEC[_sut.AbilityTier.TIER_3], 10.0, "AC-22: TIER_3 base cooldown is 10.0s")


func test_cooldown_increases_with_tier() -> void:
	assert_lt(_sut.BASE_COOLDOWN_SEC[_sut.AbilityTier.TIER_1], _sut.BASE_COOLDOWN_SEC[_sut.AbilityTier.TIER_2],
		"AC-22: TIER_2 cools down slower than TIER_1")
	assert_lt(_sut.BASE_COOLDOWN_SEC[_sut.AbilityTier.TIER_2], _sut.BASE_COOLDOWN_SEC[_sut.AbilityTier.TIER_3],
		"AC-22: TIER_3 cools down slower than TIER_2")


# --- _get_ability_tier: id → tier resolution --------------------------------------------------

func test_get_ability_tier_resolves_each_tier() -> void:
	assert_eq(_sut._get_ability_tier(_sut.AbilityId.STRIKE_TIER_1_JAB), _sut.AbilityTier.TIER_1,
		"AC-22: a …tier_1… id resolves to TIER_1")
	assert_eq(_sut._get_ability_tier(_sut.AbilityId.CONTROL_TIER_2_HOOK_PULL), _sut.AbilityTier.TIER_2,
		"AC-22: a …tier_2… id resolves to TIER_2")
	assert_eq(_sut._get_ability_tier(_sut.AbilityId.MOBILITY_TIER_3_GROUND_POUND), _sut.AbilityTier.TIER_3,
		"AC-22: a …tier_3… id resolves to TIER_3")


func test_tier_to_cooldown_end_to_end() -> void:
	# The tier resolved from each id maps to its locked cooldown value.
	var t1: int = _sut._get_ability_tier(_sut.AbilityId.STRIKE_TIER_1_JAB)
	var t3: int = _sut._get_ability_tier(_sut.AbilityId.STRIKE_TIER_3_OVERHAND)
	assert_eq(float(_sut.BASE_COOLDOWN_SEC[t1]), 3.0, "AC-22: a T1 id maps to a 3.0s cooldown")
	assert_eq(float(_sut.BASE_COOLDOWN_SEC[t3]), 10.0, "AC-22: a T3 id maps to a 10.0s cooldown")
