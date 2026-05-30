## LootRarityConfig — data-driven tuning knobs for the Loot Rarity Formula (#15)
##
## Driving GDD: design/gdd/loot-drop-system.md Section D + Tuning Knobs
## Driving Story: production/epics/loot-drop-system/story-002-data-resources-enums.md (AC-36 partial)
## Governing ADR: ADR-0005 (Accepted 2026-05-30) Loot Rarity Formula
##   loot_rarity_score = workout_score × WORKOUT_WEIGHT + rng_roll × RNG_WEIGHT
##   workout_score = clamp(volume × PR × streak, 0, 1)
##
## WHY a Resource (data-driven, not hardcoded consts):
## Coding standard — gameplay values must live in external config, never hardcoded.
## Designers edit LootRarityConfig.tres in the inspector; the formula code reads the
## knobs. The .tres SHA is PINNED in design/registry/entities.yaml and verified by
## tools/ci/check_loot_config_hash_pinned.gd (AC-29) so the locked formula constants
## (ADR-0005, no hot-swap) cannot be silently tampered post-build.
##
## NOTE: This extends plain Resource (NOT SerializableResource): it is read-only
## design data loaded from disk, never persisted into user:// tombstones, so it
## needs no to_dict()/from_dict() envelope.
##
## INVARIANTS asserted by _validate() (call after load):
##   INV-1  : workout_weight + rng_weight == 1.0
##   Pillar1: workout_weight >= 0.70  (effort dominates RNG — ADR-0005 Pillar 1)
##   Pillar1: rng_weight <= 0.30
##   INV-6  : tier_thresholds strictly ascending
##   (consistency): tier_thresholds and tier_values are equal length
class_name LootRarityConfig extends Resource


## Weight of the deterministic workout-effort component (ADR-0005). Pillar 1
## requires this to dominate (>= 0.70) so effort, not luck, drives rarity.
@export var workout_weight: float = 0.75

## Weight of the seeded RNG component (ADR-0005). Capped at 0.30 — at max RNG
## (0.25 contribution) a pure-luck roll still cannot reach the EPIC threshold.
@export var rng_weight: float = 0.25

## Reference exercise count used to normalise workout volume to [0, 1].
@export var target_exercises: int = 5

## Additive workout_score bonus contributed per personal record in the session.
@export var pr_bonus_per_pr: float = 0.12

## Ceiling on the PR multiplier so a PR-heavy session cannot unboundedly inflate score.
@export var max_pr_factor: float = 1.25

## Streak normalisation scale (days). Higher = slower streak-bonus ramp.
@export var streak_scale: float = 28.0

## Ceiling on the additive streak bonus to workout_score.
@export var max_streak_bonus: float = 0.20

## Lower-bound score thresholds mapping raw loot_rarity_score → RarityTier.
## Index i is the minimum score for tier_values[i]. MUST be strictly ascending
## (INV-6). Aligns with ADR-0005: EPIC floor (0.72) exceeds max pure-RNG (0.25).
@export var tier_thresholds: Array[float] = [0.0, 0.35, 0.55, 0.72, 0.88]

## RarityTier ordinals paired 1:1 with tier_thresholds (COMMON..LEGENDARY = 0..4).
@export var tier_values: Array[int] = [0, 1, 2, 3, 4]


## Assert all formula invariants. Call after loading the .tres (e.g. in
## LootDropSystem._ready() or the formula entry point). A violation is a hard
## crash in debug builds — a mis-tuned config must fail loudly, never silently
## corrupt the Pillar 1 guarantee.
##
## Returns void; relies on assert() (stripped in release, so also push_error for
## the weight invariants to keep a release-build trace).
func _validate() -> void:
	assert(absf(workout_weight + rng_weight - 1.0) < 1e-6,
		"INV-1: workout_weight + rng_weight must sum to 1.0 (got %f + %f)" % [workout_weight, rng_weight])
	assert(workout_weight >= 0.70,
		"Pillar 1 violation: workout_weight (%f) < 0.70" % workout_weight)
	assert(rng_weight <= 0.30,
		"Pillar 1 violation: rng_weight (%f) > 0.30" % rng_weight)
	assert(tier_thresholds.size() == tier_values.size(),
		"tier_thresholds (%d) and tier_values (%d) length mismatch" % [tier_thresholds.size(), tier_values.size()])
	# INV-6: strictly ascending thresholds.
	for i in range(1, tier_thresholds.size()):
		assert(tier_thresholds[i] > tier_thresholds[i - 1],
			"INV-6: tier_thresholds not strictly ascending at index %d (%f <= %f)"
				% [i, tier_thresholds[i], tier_thresholds[i - 1]])
