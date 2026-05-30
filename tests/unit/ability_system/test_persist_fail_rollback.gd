# Unit tests — AbilitySystem persist-fail rollback (Story 004 / AC-29).
#
# unlock_ability persists FIRST. If PersistenceLayer.write() returns false the unlock aborts BEFORE
# any in-memory mutation: _unlocked_abilities is left untouched, ability_unlocked is NOT emitted (no
# phantom unlock), and ability_unlock_save_failed fires so #28 Telemetry sees the data-integrity
# failure. The internal evaluator returns false up the chain.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


## PersistenceLayer stub whose write() ALWAYS fails. Simulates a full disk / quota-exceeded /
## Private-Mode IndexedDB rejection.
class AlwaysFailPersistence extends RefCounted:
	var write_count: int = 0

	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		write_count += 1
		return false

	func read(_key: String) -> Variant:
		return null


var _sut
var _persistence: AlwaysFailPersistence


func before_each() -> void:
	_sut = AbilitySystem.new()
	_persistence = AlwaysFailPersistence.new()
	_sut._persistence = _persistence
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null
	_persistence = null


# --- AC-29: a failed persist rolls back cleanly -----------------------------------------------

func test_persist_failure_does_not_record_unlock() -> void:
	# Act — attempt a valid unlock whose persist will fail.
	var result: bool = _sut._evaluate_unlock(
		&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — the evaluator reports failure and nothing was recorded.
	assert_false(result, "AC-29: a persist failure makes the unlock return false")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-29: a persist failure leaves _unlocked_abilities untouched (no phantom unlock)")
	assert_eq(_sut.get_unlocked_abilities().size(), 0, "AC-29: the unlock table stays empty after a failed persist")


func test_persist_failure_emits_save_failed_not_unlocked() -> void:
	# Act
	_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — ability_unlock_save_failed fired for the right id; ability_unlocked did NOT fire.
	assert_signal_emit_count(_sut, "ability_unlock_save_failed", 1,
		"AC-29: a persist failure emits exactly one ability_unlock_save_failed")
	var params: Array = get_signal_parameters(_sut, "ability_unlock_save_failed", 0)
	assert_eq(params[0], _sut.AbilityId.STRIKE_TIER_1_JAB, "AC-29: the save-failed signal carries the attempted id")
	assert_signal_emit_count(_sut, "ability_unlocked", 0,
		"AC-29: ability_unlocked must NOT fire when the persist failed")


func test_persist_was_actually_attempted() -> void:
	# Act
	_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — the write was attempted exactly once (rollback is post-attempt, not a skip).
	assert_eq(_persistence.write_count, 1, "AC-29: the persist write was attempted before the rollback decision")
