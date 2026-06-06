# AbilitySystem — Story 008 Permanent Unlock contract (AC-16) Unit Tests.
#
# Anti-Pillar constraint (Rule 12): once unlocked, ALWAYS unlocked. A stat DROP — including the
# EC-15 EQUIPMENT path — must never relock an ability. _on_stat_changed filters EQUIPMENT (ordinal
# 2) out before any evaluation, and there is no relock_ability / _unlocked_abilities.erase in the
# production path, so a falling stat leaves the unlock table untouched.
#
# This is a direct-call unit test (un-parented SUT). _on_stat_changed returns early while
# _substate == INITIALISING (the boot-burst suppression, Story 007 AC-14c); these tests force
# READY in before_each so the real post-boot evaluation path is exercised.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md Rule 12 (permanent unlock) + EC-15
# Story: production/epics/ability-system/story-008-gsm-suspended-permanent-unlock.md
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

# StatSystem StatSource ordinals (the taxonomy _on_stat_changed receives).
# G-PR-5 (2026-06-06): PR-sourced stat_changed is now EXCLUDED from Path B, so
# the arrange steps below unlock via VOLUME_TICK (1) — the legitimate Path B
# route. The relock-on-drop semantics under test are source-agnostic.
const SRC_VOLUME := 1
const SRC_EQUIPMENT := 2

var _sut
var _mock_persistence: MockPersistenceLayer


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_sut = AbilitySystem.new()
	_sut._persistence = _mock_persistence
	# Story 007: _on_stat_changed suppresses evaluation while INITIALISING. Force READY so this
	# un-parented (never-_ready) instance exercises the real post-boot path.
	_sut._substate = AbilitySystem.Substate.READY
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null
	_mock_persistence = null


# --- AC-16: a stat drop never relocks an unlocked ability -------------------------------------

func test_equipment_stat_drop_does_not_relock_unlocked_ability() -> void:
	# Arrange — STRIKE_TIER_2 unlocked at STR=50 (clears T1+T2).
	_sut._on_stat_changed(&"str", 5.0, 50.0, SRC_VOLUME, false)
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"],
		"precondition: STRIKE_TIER_2 unlocked at STR=50")

	# Act — an EQUIPMENT-sourced stat DROP to 5 (gear removed). EC-15: EQUIPMENT never evaluates.
	_sut._on_stat_changed(&"str", 50.0, 5.0, SRC_EQUIPMENT, false)

	# Assert: AC-16 — the unlock is permanent; the drop changed nothing.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"],
		"AC-16: an EQUIPMENT stat drop must NOT relock STRIKE_TIER_2 (permanent unlock)")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-16: the lower tier stays unlocked too")
	assert_eq(_sut.get_unlocked_abilities().size(), 2,
		"AC-16: the unlock table size is unchanged by the stat drop")


func test_stat_drop_does_not_call_persistence_delete() -> void:
	# Arrange — unlock STRIKE_TIER_1, then spy on deletes.
	_sut._on_stat_changed(&"str", 5.0, 10.0, SRC_VOLUME, false)
	var delete_log: Array = []
	_mock_persistence.attach_delete_spy(delete_log.append)

	# Act — EQUIPMENT stat drop.
	_sut._on_stat_changed(&"str", 10.0, 0.0, SRC_EQUIPMENT, false)

	# Assert: AC-16 — no ability.unlocked.* key is ever deleted.
	assert_eq(delete_log.size(), 0, "AC-16: a stat drop must NOT delete any persisted unlock key")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-16: STRIKE_TIER_1 remains unlocked after the drop")


func test_no_relock_api_exists() -> void:
	# AC-16 — the permanent-unlock contract forbids a relock surface. Assert no relock_ability
	# method exists on the AbilitySystem (CI lint check_ability_relock enforces at build time; this
	# is the runtime twin).
	assert_false(_sut.has_method("relock_ability"),
		"AC-16: AbilitySystem must NOT expose a relock_ability method (permanent unlock)")


func test_no_ability_relocked_signal_exists() -> void:
	# AC-16 — there must be no ability_relocked signal in the codebase.
	assert_false(_sut.has_signal("ability_relocked"),
		"AC-16: AbilitySystem must NOT declare an ability_relocked signal (permanent unlock)")
