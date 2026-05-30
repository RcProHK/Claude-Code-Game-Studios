# AbilitySystem — AC-06 CastResult enum LOCKED (Rule 5)
#
# Scope: verifies CastResult has exactly 6 outcomes in canonical order, and that
# cast_ability's return type annotation is CastResult (via a runtime sanity cast:
# casting an unlocked-less ability returns the CastResult.NOT_UNLOCKED member, an int
# enum value in [0, 6)).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md AC-06 (Rule 5); Story 002
extends GutTest


var _ability: Node = null


func before_each() -> void:
	_ability = preload("res://src/autoload/ability_system.gd").new()


func after_each() -> void:
	_ability.free()
	_ability = null


## AC-06: CastResult has exactly 6 outcomes in the canonical order.
func test_cast_result_enum_has_six_canonical_outcomes() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")
	const EXPECTED: Array[String] = [
		"SUCCESS", "NOT_UNLOCKED", "ON_COOLDOWN",
		"STAT_INSUFFICIENT", "INVALID_TARGET", "GSM_REJECT",
	]

	# Act
	var keys: Array = AbilitySystem.CastResult.keys()
	var values: Array = AbilitySystem.CastResult.values()

	# Assert
	assert_eq(values.size(), 6, "AC-06: CastResult must have exactly 6 outcomes")
	assert_eq(keys, EXPECTED, "AC-06: CastResult canonical order")
	assert_eq(int(AbilitySystem.CastResult.SUCCESS), 0, "AC-06: SUCCESS ordinal 0")
	assert_eq(int(AbilitySystem.CastResult.GSM_REJECT), 5, "AC-06: GSM_REJECT ordinal 5 (last)")


## AC-06: cast_ability returns a CastResult value (return-type contract).
## A never-unlocked ability returns CastResult.NOT_UNLOCKED — confirming the return
## is a CastResult member (the annotation enforces this at the call boundary in Godot 4.6).
func test_cast_ability_returns_cast_result_value() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")
	var AbilityId = AbilitySystem.AbilityId

	# Act — caster/target are irrelevant for the NOT_UNLOCKED precondition (Batch A stub).
	var result: int = _ability.cast_ability(AbilityId.STRIKE_TIER_1_JAB, null, null)

	# Assert — the returned value is the NOT_UNLOCKED CastResult member.
	assert_eq(result, int(AbilitySystem.CastResult.NOT_UNLOCKED),
		"AC-06: a never-unlocked cast returns CastResult.NOT_UNLOCKED")
	assert_true(result >= 0 and result < 6,
		"AC-06: cast_ability must return a value within the CastResult enum range")
