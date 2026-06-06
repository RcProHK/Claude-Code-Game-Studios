# Unit tests — AbilitySystem Path B (stat-threshold) multi-tier ascent (Story 005 / AC-11).
#
# _on_stat_changed is the Path B handler (subscribed to StatSystem.stat_changed via
# connect_for_initial_state). Given a new stat value, _evaluate_unlock_tiers unlocks EVERY
# not-yet-unlocked tier the value clears in one call — a stat jumping straight past several
# thresholds unlocks them all at once (AC-11). EQUIPMENT-sourced and sentinel/initial deliveries
# are filtered out (Rule 6).
#
# The 5-arg positional layout mirrors StatSystem's: (stat_id, old, new, source:int, is_initial).
# source is the StatSystem.StatSource INT ordinal: PR_BREAKTHROUGH=0, VOLUME_TICK=1, EQUIPMENT=2,
# DEBUG_OVERRIDE=3, INITIAL_STATE=4.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

# StatSource ordinals (StatSystem taxonomy) used by _on_stat_changed.
const SRC_PR := 0
const SRC_VOLUME := 1
const SRC_EQUIPMENT := 2
const SRC_INITIAL := 4

var _sut


func before_each() -> void:
	_sut = AbilitySystem.new()
	_sut._persistence = MockPersistenceLayer.new()
	# Batch C (Story 007): _on_stat_changed returns early while _substate == INITIALISING (it
	# suppresses unlock evaluation during the boot connect_for_initial_state burst — AC-14c). This
	# un-parented instance never runs _ready(), so it is stuck at the INITIALISING default; force it
	# to READY so these Path-B unit tests exercise the real post-boot evaluation path.
	_sut._substate = AbilitySystem.Substate.READY
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


# --- AC-11: a single large stat change unlocks all cleared tiers ------------------------------

func test_stat_jump_to_200_unlocks_all_three_strike_tiers() -> void:
	# Act — STR jumps to 200, clearing TIER_1(10), TIER_2(50) AND TIER_3(200) at once.
	_sut._on_stat_changed(&"str", 5.0, 200.0, SRC_VOLUME, false)

	# Assert — all three STRIKE tiers unlocked in one call.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"], "AC-11: T1 unlocked")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"], "AC-11: T2 unlocked")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_3_OVERHAND)["unlocked"], "AC-11: T3 unlocked")
	assert_signal_emit_count(_sut, "ability_unlocked", 3, "AC-11: exactly three unlocks for a 3-tier ascent")


func test_partial_ascent_unlocks_only_cleared_tiers() -> void:
	# Act — STR at 50 clears T1+T2 but not T3 (200).
	_sut._on_stat_changed(&"str", 5.0, 50.0, SRC_VOLUME, false)

	# Assert
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"], "AC-11: T1 unlocked")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"], "AC-11: T2 unlocked at 50")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_3_OVERHAND)["unlocked"],
		"AC-11: T3 stays locked below its 200 threshold")
	assert_signal_emit_count(_sut, "ability_unlocked", 2, "AC-11: two unlocks for a T1+T2 ascent")


func test_subsequent_change_unlocks_only_new_tiers() -> void:
	# Arrange — first reach 50 (T1+T2 unlocked).
	_sut._on_stat_changed(&"str", 5.0, 50.0, SRC_VOLUME, false)
	assert_eq(_sut.get_unlocked_abilities().size(), 2, "precondition: T1+T2 unlocked")

	# Act — later reach 200; only T3 is newly cleared (T1/T2 idempotent no-op).
	_sut._on_stat_changed(&"str", 50.0, 200.0, SRC_VOLUME, false)

	# Assert — T3 added; no double-record of T1/T2.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_3_OVERHAND)["unlocked"], "AC-11: T3 now unlocked")
	assert_eq(_sut.get_unlocked_abilities().size(), 3, "AC-11: exactly three abilities after the second ascent")


# --- Rule 6 source filtering ------------------------------------------------------------------

func test_equipment_source_unlocks_nothing() -> void:
	# Act — an EQUIPMENT-sourced change (transient gear) must never unlock.
	_sut._on_stat_changed(&"str", 5.0, 200.0, SRC_EQUIPMENT, false)

	# Assert
	assert_eq(_sut.get_unlocked_abilities().size(), 0, "Rule 6: EQUIPMENT source never unlocks an ability")


func test_initial_delivery_unlocks_nothing() -> void:
	# Act — the INITIAL_STATE sentinel burst (is_initial=true) is excluded in Batch B.
	_sut._on_stat_changed(&"str", 200.0, 200.0, SRC_INITIAL, true)

	# Assert
	assert_eq(_sut.get_unlocked_abilities().size(), 0, "Rule 6: the initial snapshot does not unlock")


func test_pr_source_is_excluded_from_path_b() -> void:
	# G-PR-5 INVERSION (#18 story 012, 2026-06-06): PR_BREAKTHROUGH-sourced
	# stat_changed must NOT unlock via Path B — the authoritative PR route is
	# Path A (_on_pr_breakthrough, reverse-wired by #18). The old assertion
	# ("the live Path A route unlocks via Path B") was the double-path bug.
	# Act
	_sut._on_stat_changed(&"dex", 5.0, 15.0, SRC_PR, false)

	# Assert — Path B stays silent for source==PR_BREAKTHROUGH.
	assert_false(_sut.get_ability_state(_sut.AbilityId.CONTROL_TIER_1_PARRY)["unlocked"],
		"G-PR-5: PR-sourced stat_changed must NOT unlock via Path B (double-path)")

	# Positive control — the same gain through Path A DOES unlock (provenance + flush).
	# Path A reads the CURRENT stat from _stat_system (the magnitude only triggers).
	_sut._stat_system = _StatStub.new()
	_sut._on_pr_breakthrough(&"dex", 0.0833)
	assert_true(_sut.get_ability_state(_sut.AbilityId.CONTROL_TIER_1_PARRY)["unlocked"],
		"Path A (_on_pr_breakthrough) is the authoritative PR unlock route")


## Minimal stat stub for the Path A positive control (DEX 15 clears CONTROL T1).
class _StatStub:
	extends RefCounted
	func get_stat(_stat_id: StringName) -> float:
		return 15.0
