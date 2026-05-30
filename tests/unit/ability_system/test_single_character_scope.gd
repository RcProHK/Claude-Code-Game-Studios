# AbilitySystem — AC-19 Single-character scope (Rule 15)
#
# Scope: verifies none of the 4 public API methods (unlock_ability, cast_ability,
# get_unlocked_abilities, get_ability_state) declare a parameter named character_id
# or char_id. The ability system is single-character MVP scope — any per-character
# parameter would be a scope-creep regression.
#
# Reflection note (Godot 4.6): `Object.get_method_list()` returns an Array of method
# Dictionaries; each has an "args" Array of {name, type, …} Dictionaries. We read the
# arg names off the 4 public methods.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md AC-19 (Rule 15); Story 002
extends GutTest


const PUBLIC_API_METHODS: Array[String] = [
	"unlock_ability",
	"cast_ability",
	"get_unlocked_abilities",
	"get_ability_state",
]

const FORBIDDEN_PARAM_NAMES: Array[String] = ["character_id", "char_id"]


var _ability: Node = null


func before_each() -> void:
	_ability = preload("res://src/autoload/ability_system.gd").new()


func after_each() -> void:
	_ability.free()
	_ability = null


## Helper — collect the parameter names of a named method via reflection.
func _param_names_for(method_name: String) -> Array[String]:
	var names: Array[String] = []
	for m: Dictionary in _ability.get_method_list():
		if m.get("name", "") != method_name:
			continue
		for arg: Dictionary in m.get("args", []):
			names.append(String(arg.get("name", "")))
		break
	return names


## AC-19: each public method exists and exposes NO character_id / char_id parameter.
func test_public_api_methods_have_no_character_id_parameter() -> void:
	for method_name: String in PUBLIC_API_METHODS:
		# Method must exist on the public surface.
		assert_true(_ability.has_method(method_name),
			"AC-19: public method '%s' must exist" % method_name)

		var param_names: Array[String] = _param_names_for(method_name)
		for forbidden: String in FORBIDDEN_PARAM_NAMES:
			assert_false(param_names.has(forbidden),
				"AC-19: '%s' must NOT declare a '%s' parameter (single-character MVP, Rule 15)" % [
					method_name, forbidden,
				])


## AC-19: positive sanity — the public signatures carry their expected ability params,
## confirming the reflection is reading real signatures (not an empty list false-negative).
func test_public_api_signatures_carry_ability_params() -> void:
	# unlock_ability(ability_id, source[, expected_class]) — must carry ability_id + source.
	var unlock_params: Array[String] = _param_names_for("unlock_ability")
	assert_true(unlock_params.has("ability_id"),
		"AC-19 sanity: unlock_ability carries 'ability_id'")
	assert_true(unlock_params.has("source"),
		"AC-19 sanity: unlock_ability carries 'source'")

	# cast_ability(ability_id, caster, target) — must carry ability_id.
	var cast_params: Array[String] = _param_names_for("cast_ability")
	assert_true(cast_params.has("ability_id"),
		"AC-19 sanity: cast_ability carries 'ability_id'")
