# AbilitySystem — AC-05 UnlockSource enum + INITIAL_STATE sentinel reject (Rule 4)
#
# Scope: verifies UnlockSource has exactly 3 members in canonical order, and that
# the INITIAL_STATE sentinel is rejected by unlock_ability (returns false + emits
# ability_mutation_rejected with reason "sentinel_misuse"). The sentinel check is
# guard (1) — it fires BEFORE the caller-whitelist guard, so this test needs no
# _unlock_call_permitted setup.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md AC-05 (Rule 4); Story 002
extends GutTest


var _ability: Node = null


func before_each() -> void:
	# Fresh un-parented instance — _ready() never runs (no DI needed for the sentinel path).
	_ability = preload("res://src/autoload/ability_system.gd").new()
	watch_signals(_ability)


func after_each() -> void:
	_ability.free()
	_ability = null


## AC-05: UnlockSource has exactly 3 members in canonical order.
func test_unlock_source_enum_has_three_canonical_members() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")

	# Act
	var keys: Array = AbilitySystem.UnlockSource.keys()

	# Assert
	assert_eq(keys, ["PR_BREAKTHROUGH", "STAT_THRESHOLD", "INITIAL_STATE"],
		"AC-05: UnlockSource canonical order = PR_BREAKTHROUGH/STAT_THRESHOLD/INITIAL_STATE")
	assert_eq(int(AbilitySystem.UnlockSource.PR_BREAKTHROUGH), 0, "AC-05: PR_BREAKTHROUGH ordinal 0")
	assert_eq(int(AbilitySystem.UnlockSource.STAT_THRESHOLD), 1, "AC-05: STAT_THRESHOLD ordinal 1")
	assert_eq(int(AbilitySystem.UnlockSource.INITIAL_STATE), 2, "AC-05: INITIAL_STATE ordinal 2 (sentinel)")


## AC-05: unlock_ability with the INITIAL_STATE sentinel returns false.
func test_unlock_ability_initial_state_sentinel_returns_false() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")
	var AbilityId = AbilitySystem.AbilityId

	# Act
	var result: bool = _ability.unlock_ability(
		AbilityId.STRIKE_TIER_1_JAB, AbilitySystem.UnlockSource.INITIAL_STATE)

	# Assert
	assert_false(result, "AC-05: INITIAL_STATE sentinel unlock must return false")


## AC-05: the sentinel reject emits ability_mutation_rejected with reason "sentinel_misuse".
func test_unlock_ability_initial_state_sentinel_emits_rejection() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")
	var AbilityId = AbilitySystem.AbilityId

	# Act
	_ability.unlock_ability(AbilityId.STRIKE_TIER_1_JAB, AbilitySystem.UnlockSource.INITIAL_STATE)

	# Assert — exactly one rejection with the canonical payload (id, source ordinal, reason).
	assert_signal_emit_count(_ability, "ability_mutation_rejected", 1,
		"AC-05: exactly one ability_mutation_rejected for the sentinel misuse")
	var params: Array = get_signal_parameters(_ability, "ability_mutation_rejected", 0)
	assert_eq(params[0], AbilityId.STRIKE_TIER_1_JAB, "AC-05: reject param 0 = ability_id")
	assert_eq(params[1], int(AbilitySystem.UnlockSource.INITIAL_STATE),
		"AC-05: reject param 1 = INITIAL_STATE ordinal (int)")
	assert_eq(params[2], "sentinel_misuse", "AC-05: reject reason must be 'sentinel_misuse'")


## AC-05: the sentinel reject does NOT unlock the ability (table untouched).
func test_unlock_ability_initial_state_sentinel_leaves_table_unchanged() -> void:
	# Arrange
	var AbilitySystem = preload("res://src/autoload/ability_system.gd")
	var AbilityId = AbilitySystem.AbilityId

	# Act
	_ability.unlock_ability(AbilityId.STRIKE_TIER_1_JAB, AbilitySystem.UnlockSource.INITIAL_STATE)

	# Assert — read API confirms no unlock landed.
	var state: Dictionary = _ability.get_ability_state(AbilityId.STRIKE_TIER_1_JAB)
	assert_false(state["unlocked"], "AC-05: sentinel reject must leave the ability locked")
