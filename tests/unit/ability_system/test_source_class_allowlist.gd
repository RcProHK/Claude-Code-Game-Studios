# Unit tests — AbilitySystem source→class allow-list + idempotent guard (Story 003).
# Covers AC-07 (cross-class unlock rejected: STR-source PR cannot unlock a CONTROL ability)
# and AC-07b (idempotent guard: re-unlocking an already-unlocked ability is a silent no-op).
#
# Cross-class enforcement runs inside _evaluate_unlock (the internal handler that derives the
# expected class from the stat_id context), which delegates to unlock_ability(..., expected_class).
# A fresh un-parented instance is used — Batch A's unlock path needs no PersistenceLayer (persist
# is deferred to Story 004).
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

var _sut


func before_each() -> void:
	_sut = AbilitySystem.new()
	# Story 004 made unlock_ability persist-FIRST; an un-parented instance never ran _ready(),
	# so _persistence is still null. Inject a write=true mock so the success path persists cleanly
	# (MockPersistenceLayer.write always returns true). Set BEFORE watch_signals so the SUT is
	# fully wired before any signal is observed.
	_sut._persistence = MockPersistenceLayer.new()
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


# --- AC-07: cross-class unlock rejected -------------------------------------------------

func test_str_source_cannot_unlock_control_ability() -> void:
	# Act — STR context (→ STRIKE) attempting a CONTROL ability via the internal evaluator.
	var result: bool = _sut._evaluate_unlock(
		&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.CONTROL_TIER_1_PARRY)

	# Assert — rejected, not recorded, telemetry fires with the canonical reason.
	assert_false(result, "AC-07: STR-source must NOT unlock a CONTROL ability")
	assert_false(_sut.get_ability_state(_sut.AbilityId.CONTROL_TIER_1_PARRY)["unlocked"],
		"AC-07: the cross-class ability must not be recorded as unlocked")
	assert_signal_emit_count(_sut, "ability_mutation_rejected", 1,
		"AC-07: exactly one rejection telemetry on the cross-class path")
	var params: Array = get_signal_parameters(_sut, "ability_mutation_rejected", 0)
	assert_eq(params[0], _sut.AbilityId.CONTROL_TIER_1_PARRY, "AC-07: rejected ability_id is CONTROL_TIER_1_PARRY")
	assert_eq(params[2], "source_class_mismatch", "AC-07: reason must be 'source_class_mismatch'")


func test_str_source_unlocks_matching_strike_ability() -> void:
	# Act — STR context (→ STRIKE) unlocking a STRIKE ability is allowed.
	var result: bool = _sut._evaluate_unlock(
		&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — allowed + recorded.
	assert_true(result, "AC-07: STR-source unlocking a STRIKE ability must succeed")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-07: the matching-class ability must be recorded as unlocked")


func test_each_stat_maps_to_its_own_class() -> void:
	# DEX → CONTROL allowed; VIT → MOBILITY allowed (Pillar 4 1:1:1 mapping).
	assert_true(_sut._evaluate_unlock(&"dex", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH,
		_sut.AbilityId.CONTROL_TIER_1_PARRY), "AC-07: DEX→CONTROL allowed")
	assert_true(_sut._evaluate_unlock(&"vit", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH,
		_sut.AbilityId.MOBILITY_TIER_1_DASH), "AC-07: VIT→MOBILITY allowed")


# --- AC-07b: idempotent guard ----------------------------------------------------------

func test_repeated_unlock_is_idempotent_noop() -> void:
	# Arrange — first unlock records the ability.
	assert_true(_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH,
		_sut.AbilityId.STRIKE_TIER_1_JAB), "precondition: first unlock succeeds")
	var count_after_first: int = _sut.get_unlocked_abilities().size()

	# Act — unlock the SAME ability again.
	var result: bool = _sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH,
		_sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — returns true (no-op) and does NOT double-record (EC-11 idempotent guard).
	assert_true(result, "AC-07b: a repeated unlock returns true (idempotent no-op)")
	assert_eq(_sut.get_unlocked_abilities().size(), count_after_first,
		"AC-07b: a repeated unlock must NOT add a second entry")
	assert_eq(count_after_first, 1, "AC-07b: exactly one ability recorded after the repeated calls")
