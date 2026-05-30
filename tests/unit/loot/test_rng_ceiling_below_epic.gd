## test_rng_ceiling_below_epic.gd — Story 003 AC-02 (Pillar 1 architectural proof)
##
## Governing story: production/epics/loot-drop-system/story-003-formula-1-pillar1-proofs.md
## Governing ADR  : ADR-0005 (Accepted 2026-05-30) Loot Rarity Formula — Pillar 1
##
## AC-02: the maximum RNG contribution (rng_weight = 0.25 at rng_roll = 1.0) is
## architecturally below the EPIC threshold (0.72). Therefore no roll — even at
## epsilon workout_score — can ever reach EPIC on luck alone. This file pins the
## proof both as a closed-form assertion and as a 10,000-iteration deterministic
## Monte Carlo sweep.
extends GutTest


# ─── Shared fixture ────────────────────────────────────────────────────────────

func _make_default_config() -> LootRarityConfig:
	var c := LootRarityConfig.new()
	c.workout_weight = 0.75
	c.rng_weight = 0.25
	c.target_exercises = 5
	c.pr_bonus_per_pr = 0.12
	c.max_pr_factor = 1.25
	c.streak_scale = 28.0
	c.max_streak_bonus = 0.20
	c.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	c.tier_values = [0, 1, 2, 3, 4]
	return c


# ─── AC-02: closed-form proof — max RNG contribution < EPIC threshold ──────────

func test_pillar1_max_rng_contribution_below_epic_threshold() -> void:
	# Arrange: the EPIC threshold and the maximum possible RNG contribution.
	var config := _make_default_config()
	var epic_threshold: float = config.tier_thresholds[3]  # index 3 = EPIC = 0.72
	var max_rng_contribution := config.rng_weight * 1.0     # rng_roll=1.0 → 0.25

	# Act + Assert: pure luck (workout_score=0) tops out at 0.25, well below 0.72.
	assert_lt(max_rng_contribution, epic_threshold,
		"Max RNG contribution (%f) must be below the EPIC threshold (%f) — Pillar 1 architectural proof" % [
			max_rng_contribution, epic_threshold,
		])


# ─── AC-02: epsilon workout_score still cannot reach EPIC raw score ────────────

func test_pillar1_epsilon_workout_score_cannot_reach_epic_raw() -> void:
	# Arrange: epsilon workout_score (0.001) with maximum RNG (1.0).
	var config := _make_default_config()
	var epsilon_ws := 0.001
	var max_rng := 1.0
	var epic_threshold: float = config.tier_thresholds[3]  # 0.72

	# Act: the largest score an epsilon workout can ever produce.
	var max_possible_score := epsilon_ws * config.workout_weight + max_rng * config.rng_weight
	# = 0.001×0.75 + 1.0×0.25 = 0.25075

	# Assert: still below the EPIC threshold.
	assert_lt(max_possible_score, epic_threshold,
		"Epsilon workout_score (0.001) max score (%f) must be below EPIC threshold (%f)" % [
			max_possible_score, epic_threshold,
		])


# ─── AC-02: deterministic Monte Carlo — 10,000 epsilon-workout rolls, zero EPIC ─

func test_pillar1_monte_carlo_epsilon_workout_zero_epic_results() -> void:
	# Arrange: epsilon workout_score with rng_roll swept deterministically across
	# 10,000 evenly-spaced values in [0.0, 0.9999]. No random seed — reproducible.
	var config := _make_default_config()
	var epsilon_ws := 0.001
	var epic_results := 0

	# Act
	for i: int in 10000:
		var rng_roll := float(i) / 10000.0
		var result := LootRarityCalc.compute_rarity_from_score(epsilon_ws, rng_roll, config)
		if result >= LootEnums.RarityTier.EPIC:
			epic_results += 1
		assert_lt(result, LootEnums.RarityTier.EPIC,
			"epsilon workout_score (0.001), rng_roll=%f must stay below EPIC (ordinal 3)" % rng_roll)

	# Assert (aggregate): zero rolls ever reached EPIC.
	assert_eq(epic_results, 0,
		"Across 10,000 epsilon-workout rolls, EPIC count must be 0 — Pillar 1 Monte Carlo proof")


# ─── AC-02 edge: pure RNG (ws=0) score sits below the COMMON threshold ─────────

func test_pillar1_pure_rng_score_below_common_threshold() -> void:
	# Arrange: workout_score=0.0, rng_roll=1.0 → score = 0.0×0.75 + 1.0×0.25 = 0.25.
	var config := _make_default_config()
	var common_threshold: float = config.tier_thresholds[1]  # index 1 = COMMON's upper neighbour (UNCOMMON=0.35)
	var pure_rng_score := 0.0 * config.workout_weight + 1.0 * config.rng_weight  # 0.25

	# Act
	var result := LootRarityCalc.compute_rarity_from_score(0.0, 1.0, config)

	# Assert: 0.25 < 0.35 → raw tier falls below UNCOMMON, so tier_from_score
	# returns COMMON (the only threshold 0.25 meets is index 0 = 0.0 = COMMON).
	assert_lt(pure_rng_score, common_threshold,
		"Pure-RNG score (%f) must be below the UNCOMMON threshold (%f) — only COMMON is reachable" % [
			pure_rng_score, common_threshold,
		])
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"workout_score=0.0, rng_roll=1.0 (score=0.25) must resolve to COMMON")
