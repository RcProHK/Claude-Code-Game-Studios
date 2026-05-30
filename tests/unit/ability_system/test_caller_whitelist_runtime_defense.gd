# Unit test — AbilitySystem caller-whitelist runtime defense (Story 003 / AC-30 / EC-10).
# unlock_ability is a closed chokepoint: only the internal _evaluate_unlock handler may invoke
# it (it flips _unlock_call_permitted true for the duration of the delegated call). A direct
# external call — simulating a non-whitelisted caller that bypassed the signal-subscription
# pattern and the CI lint — sees _unlock_call_permitted == false and is rejected.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

var _sut


func before_each() -> void:
	_sut = AbilitySystem.new()
	# Story 004 made unlock_ability persist-FIRST; an un-parented instance never ran _ready(),
	# so _persistence is still null. Inject a write=true mock so the positive-control unlock path
	# persists cleanly (MockPersistenceLayer.write always returns true). Set BEFORE watch_signals.
	_sut._persistence = MockPersistenceLayer.new()
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


## AC-30: a direct unlock_ability call (caller-whitelist not opened) is rejected.
func test_direct_unlock_call_rejected_as_caller_violation() -> void:
	# Act — call unlock_ability directly (NOT via _evaluate_unlock), so _unlock_call_permitted
	# is false (its default). This is exactly what a rogue external caller would do.
	var result: bool = _sut.unlock_ability(
		_sut.AbilityId.STRIKE_TIER_1_JAB, _sut.UnlockSource.PR_BREAKTHROUGH)

	# Assert — rejected, nothing recorded, telemetry fires with the canonical reason.
	assert_false(result, "AC-30: a non-whitelisted direct unlock_ability call must return false")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-30: a rejected unlock must not record the ability")
	assert_signal_emit_count(_sut, "ability_mutation_rejected", 1,
		"AC-30: exactly one rejection telemetry on the caller-whitelist path")
	var params: Array = get_signal_parameters(_sut, "ability_mutation_rejected", 0)
	assert_eq(params[2], "caller_whitelist_violation", "AC-30: reason must be 'caller_whitelist_violation'")


## AC-30 (positive control): the SAME unlock via the permitted internal path succeeds, proving
## the guard rejects provenance — not the unlock itself.
func test_internal_path_unlock_succeeds() -> void:
	# Act — go through the internal evaluator, which opens the whitelist window.
	var result: bool = _sut._evaluate_unlock(
		&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Assert — the same unlock now succeeds.
	assert_true(result, "AC-30: the internal (whitelisted) path must succeed")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-30: the whitelisted unlock records the ability")


## AC-30: the whitelist window is closed again after _evaluate_unlock returns, so a subsequent
## direct call is still rejected (the window does not leak).
func test_whitelist_window_closes_after_internal_call() -> void:
	# Arrange — run one internal unlock (opens then closes the window).
	_sut._evaluate_unlock(&"str", 0.0, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityId.STRIKE_TIER_1_JAB)

	# Act — a direct call afterwards must still be rejected (window did not leak).
	var result: bool = _sut.unlock_ability(
		_sut.AbilityId.STRIKE_TIER_2_HOOK, _sut.UnlockSource.PR_BREAKTHROUGH)

	# Assert
	assert_false(result, "AC-30: the whitelist window must close after _evaluate_unlock — no leak")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"],
		"AC-30: the post-window direct call records nothing")
