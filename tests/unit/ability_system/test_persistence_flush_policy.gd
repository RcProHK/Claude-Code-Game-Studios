# Unit tests — AbilitySystem per-source persistence flush policy (Story 004 / AC-13).
#
# flush_for_source decides whether unlock_ability's persist write flushes to disk immediately:
#   - PR_BREAKTHROUGH → true  (earned-it-now; a crash next frame must not lose it)
#   - STAT_THRESHOLD  → false (rides the Stat System's batched cadence)
#   - INITIAL_STATE   → false (defensive; the sentinel never reaches a persist path)
#
# A FlushSpyPersistence records the `flush` flag every write was given, so a unit test can assert
# the flag the system actually passed to PersistenceLayer.write — not just the policy function in
# isolation but the real unlock_ability → flush_for_source wiring.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


## PersistenceLayer stub that records the flush flag of every write. write() always succeeds.
class FlushSpyPersistence extends RefCounted:
	var flush_flags: Array[bool] = []

	func write(_key: String, _value: Variant, flush: bool = false) -> bool:
		flush_flags.append(flush)
		return true

	func read(_key: String) -> Variant:
		return null


var _sut
var _spy: FlushSpyPersistence


func before_each() -> void:
	_sut = AbilitySystem.new()
	_spy = FlushSpyPersistence.new()
	_sut._persistence = _spy
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null
	_spy = null


# --- flush_for_source policy (pure) -----------------------------------------------------------

func test_flush_for_source_pr_breakthrough_flushes() -> void:
	assert_true(_sut.flush_for_source(_sut.UnlockSource.PR_BREAKTHROUGH),
		"AC-13: PR_BREAKTHROUGH flushes immediately")


func test_flush_for_source_stat_threshold_defers() -> void:
	assert_false(_sut.flush_for_source(_sut.UnlockSource.STAT_THRESHOLD),
		"AC-13: STAT_THRESHOLD defers the flush")


func test_flush_for_source_initial_state_defers() -> void:
	assert_false(_sut.flush_for_source(_sut.UnlockSource.INITIAL_STATE),
		"AC-13: the INITIAL_STATE sentinel defaults to defer (defensive)")


# --- end-to-end: unlock_ability passes the policy flag to write -------------------------------

func test_pr_breakthrough_unlock_writes_with_flush_true() -> void:
	# Act — unlock a STRIKE ability via the internal evaluator under a PR provenance.
	_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — exactly one write, flushed.
	assert_eq(_spy.flush_flags.size(), 1, "AC-13: a successful unlock performs exactly one write")
	assert_true(_spy.flush_flags[0], "AC-13: a PR_BREAKTHROUGH unlock persists with flush=true")


func test_stat_threshold_unlock_writes_with_flush_false() -> void:
	# Act — unlock under the STAT_THRESHOLD provenance.
	_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.STAT_THRESHOLD, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert
	assert_eq(_spy.flush_flags.size(), 1, "AC-13: a successful unlock performs exactly one write")
	assert_false(_spy.flush_flags[0], "AC-13: a STAT_THRESHOLD unlock persists with flush=false")
