# Unit tests — AbilitySystem persist-FIRST atomic write ordering (Story 004 / AC-17).
#
# unlock_ability runs a strict T1→T2→T3 sequence:
#   T1 persist (PersistenceLayer.write) → T2 mutate _unlocked_abilities → T3 emit ability_unlocked.
# This guarantees disk and memory never diverge and no subscriber ever observes a phantom unlock.
#
# Verified by observing the SUT's own in-memory state at two checkpoints:
#   - INSIDE the persistence write spy: the ability must NOT yet be in the table (persist is FIRST,
#     before the mutate). The write spy fires during T1.
#   - INSIDE the ability_unlocked handler: the ability MUST already be in the table (emit is LAST,
#     after the mutate). The signal fires during T3.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


## PersistenceLayer stub whose write() invokes a probe BEFORE returning, so a test can inspect the
## SUT's table state at the exact moment of the persist (T1).
class ProbeWritePersistence extends RefCounted:
	var probe: Callable = Callable()

	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		if probe.is_valid():
			probe.call()
		return true

	func read(_key: String) -> Variant:
		return null


var _sut
var _persistence: ProbeWritePersistence

# Captured table state at each checkpoint.
var _unlocked_during_write: bool = true   # default true so a never-fired probe fails the assert
var _unlocked_during_emit: bool = false


func before_each() -> void:
	_sut = AbilitySystem.new()
	_persistence = ProbeWritePersistence.new()
	_persistence.probe = _capture_state_at_write
	_sut._persistence = _persistence
	_unlocked_during_write = true
	_unlocked_during_emit = false


func after_each() -> void:
	_sut.free()
	_sut = null
	_persistence = null


func _capture_state_at_write() -> void:
	# Fires during T1 (persist) — the ability must NOT yet be recorded.
	_unlocked_during_write = _sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"]


func _on_ability_unlocked(_id: StringName, _source: int) -> void:
	# Fires during T3 (emit) — the ability MUST already be recorded.
	_unlocked_during_emit = _sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"]


# --- AC-17: persist FIRST, mutate, emit LAST --------------------------------------------------

func test_persist_runs_before_in_memory_mutation() -> void:
	# Act
	_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — at persist time the ability was NOT yet in the table (persist precedes mutate).
	assert_false(_unlocked_during_write,
		"AC-17: the ability must not be in _unlocked_abilities at persist time (persist is FIRST)")


func test_emit_runs_after_in_memory_mutation() -> void:
	# Arrange — subscribe to the unlock signal so the handler samples the table at emit time.
	_sut.ability_unlocked.connect(_on_ability_unlocked)

	# Act
	_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — at emit time the ability WAS already in the table (mutate precedes emit).
	assert_true(_unlocked_during_emit,
		"AC-17: the ability must already be in _unlocked_abilities when ability_unlocked fires (emit is LAST)")
	# And the final state is unlocked.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-17: the ability ends up unlocked after the full T1→T2→T3 sequence")
