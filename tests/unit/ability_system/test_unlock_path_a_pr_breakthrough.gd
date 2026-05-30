# Unit tests — AbilitySystem Path A (PR breakthrough) unlock (Story 004 / AC-10).
#
# _on_pr_breakthrough is the PUBLIC seam reserved for the future #18 PR system. It reads the
# CURRENT stat value from the injected Stat System and delegates to _evaluate_unlock_tiers under
# the PR_BREAKTHROUGH provenance (immediate flush). A NaN / negative magnitude is a malformed PR
# event and unlocks nothing (a PR is always a positive gain).
#
# A fresh un-parented SUT is used; the DI seams are injected directly (no _ready()), so a mock
# Stat System supplies get_stat and a mock PersistenceLayer accepts the persist-first write.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


## Minimal Stat System stub — only the get_stat surface _on_pr_breakthrough touches.
class StubStatSystem extends RefCounted:
	var _value: float = 0.0

	func _init(value: float = 0.0) -> void:
		_value = value

	func get_stat(_stat_id: StringName) -> float:
		return _value


var _sut


func before_each() -> void:
	_sut = AbilitySystem.new()
	_sut._persistence = MockPersistenceLayer.new()
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


# --- AC-10: a PR breakthrough unlocks the matching-class ability at the cleared tier ----------

func test_pr_breakthrough_unlocks_tier_1_strike() -> void:
	# Arrange — STR at 15 clears TIER_1 (threshold 10) but not TIER_2 (50).
	_sut._stat_system = StubStatSystem.new(15.0)

	# Act — a PR breakthrough on STR (→ STRIKE).
	_sut._on_pr_breakthrough(&"str", 0.05)

	# Assert — STRIKE_TIER_1_JAB is unlocked; the higher tiers are not.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-10: a PR breakthrough clearing TIER_1 unlocks the matching STRIKE T1 ability")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"],
		"AC-10: a value below the TIER_2 threshold leaves T2 locked")
	assert_signal_emit_count(_sut, "ability_unlocked", 1, "AC-10: exactly one unlock emitted")
	var params: Array = get_signal_parameters(_sut, "ability_unlocked", 0)
	assert_eq(params[0], _sut.AbilityId.STRIKE_TIER_1_JAB, "AC-10: the unlocked id is STRIKE_TIER_1_JAB")
	assert_eq(params[1], _sut.UnlockSource.PR_BREAKTHROUGH, "AC-10: provenance is PR_BREAKTHROUGH (ordinal)")


func test_pr_breakthrough_respects_class_mapping() -> void:
	# Arrange — VIT at 15 maps to MOBILITY (Pillar 4 1:1).
	_sut._stat_system = StubStatSystem.new(15.0)

	# Act
	_sut._on_pr_breakthrough(&"vit", 0.05)

	# Assert — only the MOBILITY ability unlocks, never a STRIKE/CONTROL one.
	assert_true(_sut.get_ability_state(_sut.AbilityId.MOBILITY_TIER_1_DASH)["unlocked"],
		"AC-10: a VIT PR unlocks the MOBILITY class")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-10: a VIT PR must not unlock a STRIKE ability (Pillar 4)")


func test_pr_breakthrough_nan_magnitude_unlocks_nothing() -> void:
	# Arrange — even a stat value that would clear a tier must not unlock on a malformed event.
	_sut._stat_system = StubStatSystem.new(500.0)

	# Act — NaN magnitude is malformed.
	_sut._on_pr_breakthrough(&"str", NAN)

	# Assert — nothing unlocked, no telemetry.
	assert_eq(_sut.get_unlocked_abilities().size(), 0, "AC-10: a NaN-magnitude PR unlocks nothing")
	assert_signal_emit_count(_sut, "ability_unlocked", 0, "AC-10: no unlock emitted on a malformed PR")


func test_pr_breakthrough_negative_magnitude_unlocks_nothing() -> void:
	# Arrange
	_sut._stat_system = StubStatSystem.new(500.0)

	# Act — a negative magnitude is malformed (a PR is always a positive gain).
	_sut._on_pr_breakthrough(&"str", -3.0)

	# Assert
	assert_eq(_sut.get_unlocked_abilities().size(), 0, "AC-10: a negative-magnitude PR unlocks nothing")
