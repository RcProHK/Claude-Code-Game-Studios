# AbilitySystem — AC-01 AbilityId surface LOCKED (Rule 1) Unit Tests
#
# Scope: verifies the AbilityId inner class exposes exactly 9 StringName constants
# with the canonical names + lowercase values (3 classes × 3 tiers). No extra id
# (e.g. STRIKE_TIER_4) may exist — the count must be exactly 9.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md AC-01 (Rule 1); Story 002
#
# Godot 4.6 reflection note: AbilityId is an inner class (a GDScript). You CANNOT call
# the instance method `.get(name)` on the class object directly — that is a parse error
# ("Cannot call non-static function get() on the class ... Make an instance instead").
# The correct way to read an inner class's `const`s by name is
# `(AbilityId as GDScript).get_script_constant_map()`, which returns a Dictionary of
# exactly the constants declared on that inner class — enabling a precise surface lock.
extends GutTest

const ABILITY_SYSTEM := preload("res://src/autoload/ability_system.gd")


## The 9 canonical ability ids: { const-name : expected lowercase StringName value }.
const EXPECTED_IDS: Dictionary = {
	"STRIKE_TIER_1_JAB": &"strike_tier_1_jab",
	"STRIKE_TIER_2_HOOK": &"strike_tier_2_hook",
	"STRIKE_TIER_3_OVERHAND": &"strike_tier_3_overhand",
	"CONTROL_TIER_1_PARRY": &"control_tier_1_parry",
	"CONTROL_TIER_2_HOOK_PULL": &"control_tier_2_hook_pull",
	"CONTROL_TIER_3_GRAPPLE": &"control_tier_3_grapple",
	"MOBILITY_TIER_1_DASH": &"mobility_tier_1_dash",
	"MOBILITY_TIER_2_LEAP": &"mobility_tier_2_leap",
	"MOBILITY_TIER_3_GROUND_POUND": &"mobility_tier_3_ground_pound",
}


## Helper — the AbilityId inner class constant map { const_name : value }.
func _ability_id_constants() -> Dictionary:
	var ability_id: GDScript = ABILITY_SYSTEM.AbilityId
	return ability_id.get_script_constant_map()


## AC-01: every canonical constant exists with its locked lowercase StringName value.
func test_ability_id_surface_exposes_nine_canonical_constants() -> void:
	# Arrange
	var consts: Dictionary = _ability_id_constants()

	# Act + Assert — each constant resolves to its locked value.
	for const_name: String in EXPECTED_IDS:
		assert_true(consts.has(const_name),
			"AC-01: AbilityId must declare %s" % const_name)
		var value: Variant = consts.get(const_name)
		assert_eq(value, EXPECTED_IDS[const_name],
			"AC-01: AbilityId.%s must equal %s" % [const_name, EXPECTED_IDS[const_name]])
		assert_true(value is StringName,
			"AC-01: AbilityId.%s must be a StringName" % const_name)


## AC-01: the AbilityId surface is EXACTLY 9 constants — no extra id (e.g. STRIKE_TIER_4).
## With get_script_constant_map() we can now assert the surface size precisely, rather than
## probing a couple of known-absent names.
func test_ability_id_surface_has_no_extra_ids() -> void:
	# Arrange
	var consts: Dictionary = _ability_id_constants()

	# Assert — the const map is EXACTLY the 9 canonical ids, nothing more, nothing less.
	assert_eq(consts.size(), 9,
		"AC-01: AbilityId must expose exactly 9 constants — surface is locked at 9")
	for const_name: String in consts:
		assert_true(EXPECTED_IDS.has(const_name),
			"AC-01: AbilityId exposes an unexpected constant '%s' — surface is closed" % const_name)

	# Assert — a non-canonical id is NOT declared (explicit closed-surface guard).
	assert_false(consts.has("STRIKE_TIER_4"),
		"AC-01: no extra ability id (STRIKE_TIER_4) may exist — surface is locked at 9")
	assert_false(consts.has("CONTROL_TIER_4_LOCK"),
		"AC-01: no extra ability id (CONTROL_TIER_4_LOCK) may exist")


## AC-01: every ability id value matches the canonical magic-string shape
## `(strike|control|mobility)_tier_[1-3]_[a-z_]+` (the same shape the CI lint guards).
func test_ability_id_values_match_canonical_shape() -> void:
	# Arrange
	var re := RegEx.new()
	assert_eq(re.compile("^(strike|control|mobility)_tier_[1-3]_[a-z_]+$"), OK,
		"regex must compile")

	# Act + Assert
	for const_name: String in EXPECTED_IDS:
		var id_str: String = String(EXPECTED_IDS[const_name])
		assert_not_null(re.search(id_str),
			"AC-01: id '%s' must match the canonical ability-id shape" % id_str)
