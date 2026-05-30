## test_pillar1_rng_alone_never_exceeds_common.gd — Story 003 AC-01 (Pillar 1 proof)
##
## Governing story: production/epics/loot-drop-system/story-003-formula-1-pillar1-proofs.md
## Governing ADR  : ADR-0005 (Accepted 2026-05-30) Loot Rarity Formula — Pillar 1
##
## AC-01: with workout_score = 0.0, NO code path may produce a tier above COMMON,
## regardless of source-event kind, raw tier, or RNG roll. This is the anti-
## fabrication guarantee: luck alone can never manufacture loot value.
##
## Approach (the helper named in the story, _generate_rarity_with_floor(), does not
## exist — Formula 1 is split into apply_tier_ceiling_floor() + compute_rarity_from_score()):
##   (a) apply_tier_ceiling_floor(raw, kind, ws=0.0) → COMMON for every raw × kind.
##   (b) compute_rarity_from_score(0.0, rng_roll) → COMMON across 1,000 deterministic
##       rng_roll values (the zero workout_score caps the score at the RNG term,
##       which is below the COMMON threshold → floored to COMMON).
extends GutTest


const _ALL_KINDS: Array[int] = [
	LootEnums.SourceEventKind.WORKOUT_DAILY,
	LootEnums.SourceEventKind.MINI_BOSS,
	LootEnums.SourceEventKind.FINAL_BOSS,
]

const _ALL_TIERS: Array[int] = [
	LootEnums.RarityTier.COMMON,
	LootEnums.RarityTier.UNCOMMON,
	LootEnums.RarityTier.RARE,
	LootEnums.RarityTier.EPIC,
	LootEnums.RarityTier.LEGENDARY,
]


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


# ─── AC-01: zero workout_score → COMMON for every kind × raw tier ──────────────

func test_pillar1_workout_zero_all_kinds_force_common() -> void:
	# Arrange: every source-event kind crossed with every possible raw tier, ws=0.0.
	# Act + Assert: apply_tier_ceiling_floor must collapse all to COMMON.
	for kind: int in _ALL_KINDS:
		for raw_tier: int in _ALL_TIERS:
			var result := LootRarityCalc.apply_tier_ceiling_floor(raw_tier, kind, 0.0)
			assert_eq(result, LootEnums.RarityTier.COMMON,
				"ws=0.0 must force COMMON (kind=%s, raw_tier=%s) — Pillar 1 zero-workout guard" % [
					LootEnums.SourceEventKind.find_key(kind),
					LootEnums.RarityTier.find_key(raw_tier),
				])


# ─── AC-01: 1,000 deterministic rng_roll sweeps with ws=0.0 → all COMMON ───────

func test_pillar1_compute_rarity_score_zero_always_common() -> void:
	# Arrange: workout_score pinned to 0.0; rng_roll swept deterministically across
	# 1,000 evenly-spaced values in [0.0, 0.999]. No global RNG, no random seed —
	# a stable, reproducible proof.
	var config := _make_default_config()

	# Act + Assert
	for i: int in 1000:
		var rng_roll := float(i) / 1000.0
		var result := LootRarityCalc.compute_rarity_from_score(0.0, rng_roll, config)
		assert_eq(result, LootEnums.RarityTier.COMMON,
			"workout_score=0.0, rng_roll=%f must yield COMMON (max score=0.25 < COMMON threshold 0.35)" % rng_roll)


# ─── AC-01 edge: zero-workout guard outranks the FINAL_BOSS floor ──────────────

func test_pillar1_zero_workout_overrides_final_boss_floor() -> void:
	# Arrange: a final-boss kill (which normally floors to UNCOMMON) with a
	# LEGENDARY raw tier — but no workout signal at all.
	var raw_tier := LootEnums.RarityTier.LEGENDARY
	var kind := LootEnums.SourceEventKind.FINAL_BOSS

	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(raw_tier, kind, 0.0)

	# Assert: the zero-workout guard (priority 1) beats the final-boss floor.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"ws=0.0 must override the FINAL_BOSS UNCOMMON floor — zero-workout guard is highest priority")


# ─── AC-01 edge: zero-workout guard outranks the MINI_BOSS ceiling path ────────

func test_pillar1_zero_workout_overrides_mini_boss_ceiling() -> void:
	# Arrange: a mini-boss kill with a RARE raw tier, but no workout signal.
	var raw_tier := LootEnums.RarityTier.RARE
	var kind := LootEnums.SourceEventKind.MINI_BOSS

	# Act
	var result := LootRarityCalc.apply_tier_ceiling_floor(raw_tier, kind, 0.0)

	# Assert: the zero-workout guard short-circuits before the dual-gate runs.
	assert_eq(result, LootEnums.RarityTier.COMMON,
		"ws=0.0 must force COMMON on a MINI_BOSS before the dual-gate ceiling logic runs")
