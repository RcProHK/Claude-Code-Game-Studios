## LootRarityCalc — pure static implementation of Formula 1 (Loot Rarity).
##
## Driving GDD : design/gdd/loot-drop-system.md Section D + Formula 1
## Driving Story: production/epics/loot-drop-system/story-003-formula-1-pillar1-proofs.md
## Governing ADR: ADR-0005 (Accepted 2026-05-30) Loot Rarity Formula
##   loot_rarity_score = workout_score × WORKOUT_WEIGHT + rng_roll × RNG_WEIGHT
##   final_tier        = max(raw_tier, COMMON)   (Pillar 3 floor)
##
## WHY a pure static class (NOT an autoload):
## Formula 1 is a stateless O(1) computation invoked once per loot-granting event.
## It holds no state, emits no signals, persists nothing. Making it a RefCounted-
## with-static-funcs keeps it dependency-neutral (importable by Story 004 Formula 2,
## Story 009 autoload, and the unit tests) without registering an autoload singleton.
## All gameplay constants are read from LootRarityConfig (data-driven, ADR-0005) —
## NO formula constant is re-derived here.
##
## ANTI-FABRICATION (ADR-0005 Pillar 1): the RNG roll is ALWAYS seeded from
## transition_id (hash-stable), NEVER from the global randf()/randi() generator
## (CI lint AC-26). Max RNG contribution (rng_weight = 0.25) is architecturally
## below the EPIC threshold (0.72), so pure luck can never fabricate a top tier
## without a real workout signal.
class_name LootRarityCalc
extends RefCounted


## Canonical config path. Aligned with Story 002 (CI lint requires the assets/
## data path, not a bare data/ path).
const _DEFAULT_CONFIG_PATH := "res://assets/data/loot/loot_rarity_config.tres"


## Compute the final RarityTier ordinal for a loot-granting workout event.
##
## Reads tuning knobs from `config`; if null, loads the canonical
## LootRarityConfig.tres. Applies the ADR-0005 two-stage formula and the Pillar 3
## floor (final_tier = max(raw_tier, COMMON)). Note: this entry point does NOT
## apply source-event ceiling/floor — call apply_tier_ceiling_floor() for that.
##
## Example:
##   var tier := LootRarityCalc.compute_rarity(5, 1, 30, "T-deadbeef", null)
##   # tier == LootEnums.RarityTier.LEGENDARY for a peak workout
##
## @param completed_exercises  Exercises completed this session (volume signal).
## @param pr_breakthrough_count Personal records broken this session.
## @param streak_count         Consecutive-day streak (days).
## @param transition_id        Stable seed source for the RNG roll (anti-fabrication).
## @param config               LootRarityConfig, or null to load the default .tres.
## @return                     RarityTier ordinal, floored at COMMON (Pillar 3).
static func compute_rarity(
	completed_exercises: int,
	pr_breakthrough_count: int,
	streak_count: int,
	transition_id: String,
	config: LootRarityConfig = null
) -> int:
	if config == null:
		config = load(_DEFAULT_CONFIG_PATH)
	var ws := _compute_workout_score(
		completed_exercises, pr_breakthrough_count, streak_count, config
	)
	var rng_roll := _compute_rng_roll(transition_id)
	var loot_score := clampf(
		ws * config.workout_weight + rng_roll * config.rng_weight, 0.0, 1.0
	)
	var raw_tier := tier_from_score(loot_score, config)
	# Pillar 3 floor: a real workout event always yields at least COMMON.
	return maxi(raw_tier, LootEnums.RarityTier.COMMON)


## Apply source-event ceiling/floor rules on top of a raw tier (Formula 1, Rule
## 4/5/8). Logic order is LOAD-BEARING and MUST NOT be reordered:
##   1. Zero-workout guard (highest priority — INV-11): ws == 0.0 forces COMMON,
##      overriding every source-event rule (no item is ever fabricated without a
##      real workout signal, even on a boss kill).
##   2. FINAL_BOSS floor (Rule 5): lift to at least UNCOMMON.
##   3. MINI_BOSS dual-gate (Rule 4): hard RARE ceiling AND a workout-score tier
##      ceiling floor(ws × 5), then Pillar 3 COMMON floor.
##   4. WORKOUT_DAILY / other: Pillar 3 COMMON floor only.
##
## Example:
##   apply_tier_ceiling_floor(EPIC, MINI_BOSS, 0.78)  == RARE      (hard ceiling)
##   apply_tier_ceiling_floor(COMMON, FINAL_BOSS, 0.4) == UNCOMMON (floor lift)
##   apply_tier_ceiling_floor(LEGENDARY, WORKOUT_DAILY, 0.0) == COMMON (zero guard)
##
## @param raw_tier RarityTier ordinal produced by tier_from_score / compute_rarity.
## @param kind     LootEnums.SourceEventKind ordinal of the triggering event.
## @param ws       The workout_score that produced raw_tier (for the dual-gate).
## @return         RarityTier ordinal after ceiling/floor rules.
static func apply_tier_ceiling_floor(raw_tier: int, kind: int, ws: float) -> int:
	# 1. Zero-workout guard — highest priority (INV-11). No source-event rule may
	#    fabricate value when there was no workout signal.
	if ws == 0.0:
		return LootEnums.RarityTier.COMMON
	# 2. FINAL_BOSS floor (Rule 5): at least UNCOMMON, no ceiling.
	if kind == LootEnums.SourceEventKind.FINAL_BOSS:
		return maxi(raw_tier, LootEnums.RarityTier.UNCOMMON)
	# 3. MINI_BOSS dual-gate (Rule 4): hard RARE ceiling AND workout-score ceiling.
	if kind == LootEnums.SourceEventKind.MINI_BOSS:
		var ws_ceiling := int(floor(clampf(ws, 0.0, 1.0) * 5.0))
		var hard_cap := LootEnums.RarityTier.RARE
		var capped := mini(raw_tier, hard_cap)
		capped = mini(capped, ws_ceiling)
		# Pillar 3 floor.
		return maxi(capped, LootEnums.RarityTier.COMMON)
	# 4. WORKOUT_DAILY (or any other kind): Pillar 3 COMMON floor only.
	return maxi(raw_tier, LootEnums.RarityTier.COMMON)


## Map a raw loot_rarity_score to a RarityTier ordinal using the data-driven
## thresholds in `config`. Iterates tier_thresholds DESCENDING (high → low) and
## returns the tier_value of the first threshold the score meets or exceeds.
##
## Because tier_thresholds[0] is 0.0 and scores are clamped to [0, 1], the loop
## always matches; the COMMON fallback is a defensive guard for a malformed config.
##
## @param score  Clamped loot_rarity_score in [0.0, 1.0].
## @param config LootRarityConfig holding tier_thresholds / tier_values.
## @return       RarityTier ordinal for the score.
static func tier_from_score(score: float, config: LootRarityConfig) -> int:
	for i in range(config.tier_thresholds.size() - 1, -1, -1):
		if score >= config.tier_thresholds[i]:
			return config.tier_values[i]
	return LootEnums.RarityTier.COMMON


## Test/helper entry point: compute a raw tier directly from a precomputed
## workout_score and rng_roll (bypassing exercise/PR/streak derivation and the
## seeded RNG). Used by the Pillar 1 proofs to sweep rng_roll deterministically.
## Returns the RAW tier from tier_from_score (no source-event ceiling/floor).
##
## @param workout_score Precomputed workout_score in [0.0, 1.0].
## @param rng_roll      RNG roll in [0.0, 1.0].
## @param config        LootRarityConfig, or null to load the default .tres.
## @return              RarityTier ordinal from tier_from_score.
static func compute_rarity_from_score(
	workout_score: float, rng_roll: float, config: LootRarityConfig = null
) -> int:
	if config == null:
		config = load(_DEFAULT_CONFIG_PATH)
	var score := clampf(
		workout_score * config.workout_weight + rng_roll * config.rng_weight, 0.0, 1.0
	)
	return tier_from_score(score, config)


## Derive the deterministic workout_score (Pillar 1 signal) from session metrics.
## Multiplicative: ALL signals must contribute for a high score (ADR-0005).
##   volume        = min(1.0, exercises / target_exercises)
##   pr_factor     = min(max_pr_factor, 1.0 + pr_bonus_per_pr × prs)
##   streak_factor = 1.0 + min(streak / streak_scale, max_streak_bonus)
##   workout_score = clamp(volume × pr_factor × streak_factor, 0, 1)
static func _compute_workout_score(
	exercises: int, prs: int, streak: int, config: LootRarityConfig
) -> float:
	var volume := minf(1.0, float(exercises) / float(config.target_exercises))
	var pr_factor := minf(config.max_pr_factor, 1.0 + config.pr_bonus_per_pr * float(prs))
	var streak_factor := 1.0 + minf(
		float(streak) / config.streak_scale, config.max_streak_bonus
	)
	return clampf(volume * pr_factor * streak_factor, 0.0, 1.0)


## Seeded RNG roll for the secondary excitement component. The seed is ALWAYS
## derived from transition_id (hash-stable) — never the global RNG (ADR-0005
## Pillar 1, CI lint AC-26) — so the roll is deterministic and reproducible.
static func _compute_rng_roll(transition_id: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(transition_id)
	return rng.randf()
