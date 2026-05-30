# Unit tests — AbilitySystem Formula 3 deterministic unlock event ordering (Story 005 / AC-23).
#
# When one stat change clears multiple tiers, the ability_unlocked signals MUST fire in a fixed,
# deterministic order: sorted by the composite key tier_ordinal*4 + class_ordinal. Within a single
# stat's ascent the class is fixed, so the order degenerates to ascending tier (T1 → T2 → T3).
#
# Determinism is the property under test, so the multi-tier ascent is repeated 100x on a fresh SUT
# each iteration and the emitted id sequence is asserted identical every run. No RNG, no time, no
# frame dependence (test-standards determinism rule).
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")

const ITERATIONS := 100


func _collect_unlock_order(value: float) -> Array[StringName]:
	# Build a fresh SUT, drive a single multi-tier ascent, and capture the unlock id sequence.
	var sut = AbilitySystem.new()
	sut._persistence = MockPersistenceLayer.new()
	var order: Array[StringName] = []
	sut.ability_unlocked.connect(func(id: StringName, _source: int) -> void: order.append(id))
	sut._evaluate_unlock_tiers(&"str", value, sut.UnlockSource.STAT_THRESHOLD)
	sut.free()
	return order


# --- AC-23: a 3-tier ascent fires T1 → T2 → T3 in that exact order, every time ----------------

func test_three_tier_ascent_order_is_ascending_tier() -> void:
	var order: Array[StringName] = _collect_unlock_order(200.0)
	var expected: Array[StringName] = [
		AbilitySystem.AbilityId.STRIKE_TIER_1_JAB,
		AbilitySystem.AbilityId.STRIKE_TIER_2_HOOK,
		AbilitySystem.AbilityId.STRIKE_TIER_3_OVERHAND,
	]
	assert_eq(order, expected, "AC-23: a 3-tier ascent fires T1 → T2 → T3 in ascending tier order")


func test_unlock_order_is_deterministic_across_100_runs() -> void:
	var baseline: Array[StringName] = _collect_unlock_order(200.0)
	assert_eq(baseline.size(), 3, "precondition: the baseline ascent unlocked 3 tiers")

	var all_identical := true
	for i in range(ITERATIONS):
		var run: Array[StringName] = _collect_unlock_order(200.0)
		if run != baseline:
			all_identical = false
			break
	assert_true(all_identical,
		"AC-23: the unlock event order is identical across %d runs (deterministic, no RNG/time)" % ITERATIONS)
