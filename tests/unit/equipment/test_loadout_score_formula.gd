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
		&"attack_power": 84.0,
		&"max_hp": 160.0,
		&"move_speed": 25.0,
		&"crit_chance": 0.06,
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
		LoadoutScoreCalc.loadout_score({ &"crit_chance": 0.06 }), 24.0, 0.0001)


func test_unknown_key_scores_zero() -> void:
	# D8 guard should have dropped it upstream; the formula defends in depth.
	assert_eq(LoadoutScoreCalc.loadout_score({ &"STR": 999.0 }), 0.0)


func test_injected_zero_weight_silences_a_key() -> void:
	# Knob behaviour: weights are injectable (data-driven).
	var weights: Dictionary = { &"attack_power": 0.0, &"max_hp": 0.25 }
	var score: float = LoadoutScoreCalc.loadout_score(
		{ &"attack_power": 90.0, &"max_hp": 100.0 }, weights)
	assert_almost_eq(score, 25.0, 0.0001)
