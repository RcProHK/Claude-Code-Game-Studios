# Unit tests — AbilitySystem cooldown tick (Story 006 / AC-18).
#
# _process(delta) decrements every live cooldown by delta, clamped to MAX_FRAME_DELTA (bfcache
# safety — a tab resumed from the back-forward cache delivers one multi-second delta that must not
# evaporate a cooldown). When a cooldown reaches <= 0 it is erased and ability_cooldown_ended fires;
# when the last cooldown clears, _process is disabled (idle = 0 CPU).
#
# _process is driven directly (no add_child / frame loop) so the tick math is deterministic and
# frame-independent (test-standards determinism rule).
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

var _sut


func before_each() -> void:
	_sut = AbilitySystem.new()
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


# --- AC-18: a tick decrements the cooldown ----------------------------------------------------

func test_tick_decrements_cooldown() -> void:
	# Arrange — start a TIER_1 cooldown (3.0s).
	_sut._start_cooldown(_sut.AbilityId.STRIKE_TIER_1_JAB)
	var before: float = _sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["cooldown_remaining"]

	# Act — one tick of 0.1s (== MAX_FRAME_DELTA, not clamped).
	_sut._process(0.1)

	# Assert
	var after: float = _sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["cooldown_remaining"]
	assert_almost_eq(after, before - 0.1, 0.0001, "AC-18: a tick decrements the cooldown by delta")


func test_large_delta_is_clamped_to_max_frame_delta() -> void:
	# Arrange — start a TIER_1 cooldown (3.0s).
	_sut._start_cooldown(_sut.AbilityId.STRIKE_TIER_1_JAB)

	# Act — a 30s bfcache resume spike. The clamp caps the decrement at MAX_FRAME_DELTA (0.1).
	_sut._process(30.0)

	# Assert — the cooldown did NOT evaporate; it dropped by at most 0.1, not 30.
	var remaining: float = _sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["cooldown_remaining"]
	assert_almost_eq(remaining, 3.0 - _sut.MAX_FRAME_DELTA, 0.0001,
		"AC-18: a multi-second delta is clamped to MAX_FRAME_DELTA so the cooldown survives the resume")
	assert_gt(remaining, 0.0, "AC-18: the cooldown is still live after a clamped spike")


func test_cooldown_expiry_emits_ended_and_erases() -> void:
	# Arrange — start a TIER_1 cooldown (3.0s).
	_sut._start_cooldown(_sut.AbilityId.STRIKE_TIER_1_JAB)

	# Act — tick 30 times at the clamp ceiling (30 * 0.1 = 3.0s) to drain the full cooldown.
	for i in range(30):
		_sut._process(0.1)

	# Assert — the cooldown is cleared and ability_cooldown_ended fired exactly once.
	assert_eq(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["cooldown_remaining"], 0.0,
		"AC-18: the cooldown is erased once it reaches zero")
	assert_signal_emit_count(_sut, "ability_cooldown_ended", 1, "AC-18: ability_cooldown_ended fires once on expiry")
	var params: Array = get_signal_parameters(_sut, "ability_cooldown_ended", 0)
	assert_eq(params[0], _sut.AbilityId.STRIKE_TIER_1_JAB, "AC-18: cooldown_ended carries the right ability id")


func test_process_disabled_when_last_cooldown_clears() -> void:
	# Arrange — a single live cooldown, drained to zero.
	_sut._start_cooldown(_sut.AbilityId.STRIKE_TIER_1_JAB)
	for i in range(30):
		_sut._process(0.1)

	# Assert — with no live cooldowns, _process is turned off (idle = 0 CPU).
	assert_false(_sut.is_processing(), "AC-18: _process is disabled once the last cooldown clears")
