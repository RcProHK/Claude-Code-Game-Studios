# LoadoutScoreCalc — Story 007: Formula 1 loadout_score (pure static).
#
# Scope (GDD Formula 1):
#   AC-18 — golden vector: 3×LEGENDARY fresh account effective
#           {ATK 84, HP 160, MOVE 25, CRIT 0.06} → 163.0
#   Formula behaviour: empty → 0; per-key weight normalization; zero-weight knob
#   (AC-19's swap-decision lives in Story 006's orchestration tests)
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-007-loadout-score-formula.md
extends GutTest


func test_golden_vector_three_legendary_fresh_account_is_163() -> void:
	# Arrange — post-clamp effective aggregate (cap 84 binds the L weapon's 90)
	var effective: Dictionary = {
		&"ATTACK_POWER": 84.0,
		&"MAX_HP": 160.0,
		&"MOVE_SPEED": 25.0,
		&"CRIT_CHANCE": 0.06,
	}

	# Act
	var score: float = LoadoutScoreCalc.loadout_score(effective)

	# Assert — 84 + 40 + 15 + 24 = 163 (AC-18)
	assert_almost_eq(score, 163.0, 0.0001)


func test_empty_aggregate_scores_zero() -> void:
	# Empty slots contribute 0 — the empty-slot baseline (Rule 6).
	assert_eq(LoadoutScoreCalc.loadout_score({}), 0.0)


func test_single_crit_key_normalizes_via_400_weight() -> void:
	# 0.01-scale CRIT delta needs the 400 weight to compete (per-key scales).
	assert_almost_eq(
		LoadoutScoreCalc.loadout_score({ &"CRIT_CHANCE": 0.06 }), 24.0, 0.0001)


func test_unknown_key_scores_zero() -> void:
	# D8 guard should have dropped it upstream; the formula defends in depth.
	assert_eq(LoadoutScoreCalc.loadout_score({ &"STR": 999.0 }), 0.0)


func test_injected_zero_weight_silences_a_key() -> void:
	# Knob behaviour: weights are injectable (data-driven).
	var weights: Dictionary = { &"ATTACK_POWER": 0.0, &"MAX_HP": 0.25 }
	var score: float = LoadoutScoreCalc.loadout_score(
		{ &"ATTACK_POWER": 90.0, &"MAX_HP": 100.0 }, weights)
	assert_almost_eq(score, 25.0, 0.0001)
