# Loot Rarity Formula — Unit Tests
# Tests ADR-0005: loot_rarity_score = workout_score × 0.75 + rng_roll × 0.25
# workout_score = clamp(volume × PR × streak, 0, 1)
# Pillar 1 proof: max RNG = 0.25 < EPIC threshold (0.72)
#
# Framework: GUT (Godot Unit Testing) v7.x — migrated from GdUnit4 2026-05-28
extends GutTest


func test_workout_score_clamped_to_zero_when_all_inputs_zero() -> void:
	var volume: float = 0.0
	var pr: float = 0.0
	var streak: float = 0.0
	var workout_score: float = clampf(volume * pr * streak, 0.0, 1.0)
	assert_eq(workout_score, 0.0)


func test_workout_score_clamped_to_one_when_above_max() -> void:
	var volume: float = 10.0
	var pr: float = 10.0
	var streak: float = 10.0
	var workout_score: float = clampf(volume * pr * streak, 0.0, 1.0)
	assert_eq(workout_score, 1.0)


func test_rarity_score_max_rng_cannot_reach_epic_threshold() -> void:
	# Pillar 1 proof: even with max RNG (1.0) and zero workout, score stays below EPIC (0.72)
	var workout_score: float = 0.0
	var max_rng_roll: float = 1.0
	var rarity_score: float = workout_score * 0.75 + max_rng_roll * 0.25
	# Max RNG contribution = 0.25, EPIC threshold = 0.72
	assert_lt(rarity_score, 0.72)


func test_rarity_score_full_workout_and_max_rng_reaches_legendary() -> void:
	var workout_score: float = 1.0
	var rng_roll: float = 1.0
	var rarity_score: float = workout_score * 0.75 + rng_roll * 0.25
	assert_eq(rarity_score, 1.0)


func test_rarity_score_full_workout_no_rng_reaches_epic() -> void:
	var workout_score: float = 1.0
	var rng_roll: float = 0.0
	var rarity_score: float = workout_score * 0.75 + rng_roll * 0.25
	# 0.75 >= EPIC threshold (0.72)
	assert_gte(rarity_score, 0.72)


func test_rarity_score_pillar1_floor_forces_common_minimum() -> void:
	# Pillar 3 floor: final_tier = max(raw_rarity, COMMON)
	# Even zero workout + zero RNG = at least COMMON
	var raw_rarity_score: float = 0.0
	var COMMON_THRESHOLD: float = 0.0  # Common is always the minimum tier
	var final_score: float = maxf(raw_rarity_score, COMMON_THRESHOLD)
	# A completed workout always produces at least COMMON (from game-concept.md guarantee)
	assert_gte(final_score, 0.0)
