# AbilitySystem — AC-03 AbilityClass + AbilityTier enums LOCKED (ADR-0007 Family B)
#
# Scope: verifies AbilityClass is the 4-value Family B enum per ADR-0007
# (STRIKE=0/CONTROL=1/MOBILITY=2/UNKNOWN=3, sentinel LAST) and AbilityTier is the
# 3-value enum (TIER_1/TIER_2/TIER_3). GDD AC-03 specified 3 AbilityClass values;
# ADR-0007 (Accepted 2026-05-29) locks 4 by adding the UNKNOWN sentinel — ADR-0007
# takes precedence.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md AC-03; ADR-0007 Family B; Story 002
extends GutTest


## AC-03: AbilityClass has exactly 4 values (ADR-0007 — adds the UNKNOWN sentinel).
func test_ability_class_enum_has_exactly_four_values() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")

	# Act
	var values: Array = AbilitySystem.AbilityClass.values()

	# Assert
	assert_eq(values.size(), 4,
		"AC-03: AbilityClass must have exactly 4 values (ADR-0007 Family B — UNKNOWN sentinel added)")


## AC-03: declaration order is load-bearing — STRIKE=0/CONTROL=1/MOBILITY=2/UNKNOWN=3.
func test_ability_class_enum_ordinals_are_canonical() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")

	# Assert — ordinals fixed (Formula 3 emit ordering + #9 tiebreak depend on this).
	assert_eq(int(AbilitySystem.AbilityClass.STRIKE), 0, "AC-03: STRIKE ordinal 0 (a REAL class, not a safe default)")
	assert_eq(int(AbilitySystem.AbilityClass.CONTROL), 1, "AC-03: CONTROL ordinal 1")
	assert_eq(int(AbilitySystem.AbilityClass.MOBILITY), 2, "AC-03: MOBILITY ordinal 2")
	assert_eq(int(AbilitySystem.AbilityClass.UNKNOWN), 3, "AC-03: UNKNOWN sentinel ordinal 3 (LAST per ADR-0007)")


## AC-03: the UNKNOWN sentinel is the LAST key (anti-fabrication — never at ordinal 0).
func test_ability_class_unknown_sentinel_is_last() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")

	# Act
	var keys: Array = AbilitySystem.AbilityClass.keys()

	# Assert — UNKNOWN is the final declared key; STRIKE (a real class) is first.
	assert_eq(keys[0], "STRIKE", "AC-03: STRIKE is declared first (ordinal 0)")
	assert_eq(keys[keys.size() - 1], "UNKNOWN",
		"AC-03: UNKNOWN must be the LAST member (ADR-0007 anti-fabrication sentinel)")


## AC-03: the 4 canonical member names are exactly present (no NEUTRAL — ADR-0007 retired it).
func test_ability_class_member_names_are_canonical() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")
	const EXPECTED: Array[String] = ["STRIKE", "CONTROL", "MOBILITY", "UNKNOWN"]

	# Act
	var keys: Array = AbilitySystem.AbilityClass.keys()

	# Assert
	assert_eq(keys.size(), 4, "AC-03: exactly 4 keys")
	for member_name: String in EXPECTED:
		assert_true(AbilitySystem.AbilityClass.has(member_name),
			"AC-03: AbilityClass must contain '%s'" % member_name)
	assert_false(AbilitySystem.AbilityClass.has("NEUTRAL"),
		"AC-03: NEUTRAL is retired as an AbilityClass member (ADR-0007) — must NOT be present")


## AC-03: AbilityTier has exactly 3 values in canonical order TIER_1/TIER_2/TIER_3.
func test_ability_tier_enum_has_three_canonical_values() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")

	# Act
	var values: Array = AbilitySystem.AbilityTier.values()
	var keys: Array = AbilitySystem.AbilityTier.keys()

	# Assert
	assert_eq(values.size(), 3, "AC-03: AbilityTier must have exactly 3 values")
	assert_eq(keys, ["TIER_1", "TIER_2", "TIER_3"], "AC-03: AbilityTier canonical order")
	assert_eq(int(AbilitySystem.AbilityTier.TIER_1), 0, "AC-03: TIER_1 ordinal 0")
	assert_eq(int(AbilitySystem.AbilityTier.TIER_2), 1, "AC-03: TIER_2 ordinal 1")
	assert_eq(int(AbilitySystem.AbilityTier.TIER_3), 2, "AC-03: TIER_3 ordinal 2")
