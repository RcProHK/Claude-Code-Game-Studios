# CombatResolver — Story 005 Formula 4 (classify_damage_tier) Unit Tests.
#
# Scope:
#   * AC-16 — tier boundary classification at the GDD thresholds (ratio of max_hp,
#             `>=` inclusive lower bounds): 0.01 LIGHT / 0.05 MEDIUM / 0.15 HEAVY /
#             0.40 CRITICAL. A hit landing EXACTLY on a threshold promotes to the
#             higher tier.
#   * AC-17 — crit override: is_crit forces tier ≥ HEAVY even when the ratio would
#             classify NEGLIGIBLE/LIGHT/MEDIUM (FR Test #4 — preserves crit hit-feel
#             on bullet-sponge targets).
#   * AC-30 — max_hp guard: target_max_hp == 1 must not crash (div-by-zero guard
#             via max(1, ...)) and yields CRITICAL for any damage ≥ 1.
#
# ── DIVERGENCE FROM STORY AC-16 (intentional — GDD is ground truth) ──
# The story's AC-16 table listed [9 → LIGHT] and [400 → HEAVY], which contradict
# design/gdd/combat-resolver.md Formula 4. Per coding-standards (balance values
# follow their SOURCE FORMULA), these tests use the GDD-correct boundary values:
#   5→NEGLIGIBLE, 10→LIGHT(0.01 exact), 50→MEDIUM(0.05 exact), 149→MEDIUM,
#   150→HEAVY(0.15 exact), 400→CRITICAL(0.40 exact), 401→CRITICAL
# (all against max_hp=1000). The 9→LIGHT / 400→HEAVY entries were story-text typos
# — 9/1000 = 0.009 < T_LIGHT(0.01) ⇒ NEGLIGIBLE, and 400/1000 = 0.40 == T_CRITICAL
# ⇒ CRITICAL (not HEAVY). The orchestrator realigns the story AC-16 text to match.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Formula 4 (thresholds + crit override)
# Story: production/epics/combat-resolver/story-005-tier-overkill.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")

const MAX_HP: int = 1000  # ratio denominator — keeps each boundary a clean fraction


# ── AC-16: tier boundary classification (GDD-correct values) ──────────────────

## AC-16: 5/1000 = 0.005 < T_LIGHT(0.01) → NEGLIGIBLE.
func test_classify_tier_5_of_1000_is_negligible() -> void:
	var tier = CombatResolver.classify_damage_tier(5, MAX_HP, false)
	assert_eq(tier, CombatResolver.DamageTier.NEGLIGIBLE, "AC-16: 0.005 < 0.01 → NEGLIGIBLE")


## AC-16: 10/1000 = 0.01 == T_LIGHT → LIGHT (inclusive lower bound promotes).
func test_classify_tier_10_of_1000_is_light_exact_boundary() -> void:
	var tier = CombatResolver.classify_damage_tier(10, MAX_HP, false)
	assert_eq(tier, CombatResolver.DamageTier.LIGHT, "AC-16: 0.01 == T_LIGHT (>= inclusive) → LIGHT")


## AC-16: 50/1000 = 0.05 == T_MEDIUM → MEDIUM (exact boundary).
func test_classify_tier_50_of_1000_is_medium_exact_boundary() -> void:
	var tier = CombatResolver.classify_damage_tier(50, MAX_HP, false)
	assert_eq(tier, CombatResolver.DamageTier.MEDIUM, "AC-16: 0.05 == T_MEDIUM (>= inclusive) → MEDIUM")


## AC-16: 149/1000 = 0.149 < T_HEAVY(0.15) → MEDIUM (just below the HEAVY line).
func test_classify_tier_149_of_1000_is_medium() -> void:
	var tier = CombatResolver.classify_damage_tier(149, MAX_HP, false)
	assert_eq(tier, CombatResolver.DamageTier.MEDIUM, "AC-16: 0.149 < 0.15 → MEDIUM")


## AC-16: 150/1000 = 0.15 == T_HEAVY → HEAVY (exact boundary).
func test_classify_tier_150_of_1000_is_heavy_exact_boundary() -> void:
	var tier = CombatResolver.classify_damage_tier(150, MAX_HP, false)
	assert_eq(tier, CombatResolver.DamageTier.HEAVY, "AC-16: 0.15 == T_HEAVY (>= inclusive) → HEAVY")


## AC-16: 400/1000 = 0.40 == T_CRITICAL → CRITICAL (exact boundary).
## NOTE: story text said HEAVY here — that is a typo; 0.40 == T_CRITICAL ⇒ CRITICAL.
func test_classify_tier_400_of_1000_is_critical_exact_boundary() -> void:
	var tier = CombatResolver.classify_damage_tier(400, MAX_HP, false)
	assert_eq(tier, CombatResolver.DamageTier.CRITICAL, "AC-16: 0.40 == T_CRITICAL (>= inclusive) → CRITICAL")


## AC-16: 401/1000 = 0.401 > T_CRITICAL → CRITICAL.
func test_classify_tier_401_of_1000_is_critical() -> void:
	var tier = CombatResolver.classify_damage_tier(401, MAX_HP, false)
	assert_eq(tier, CombatResolver.DamageTier.CRITICAL, "AC-16: 0.401 > 0.40 → CRITICAL")


# ── AC-17: crit override (is_crit forces tier ≥ HEAVY) ────────────────────────

## AC-17: a crit on a tiny-ratio hit (would be NEGLIGIBLE) overrides to HEAVY.
func test_classify_tier_crit_overrides_negligible_to_heavy() -> void:
	# Arrange — 5/1000 = 0.005 would be NEGLIGIBLE without the crit override.
	var tier = CombatResolver.classify_damage_tier(5, MAX_HP, true)

	# Assert
	assert_eq(tier, CombatResolver.DamageTier.HEAVY, "AC-17: crit forces NEGLIGIBLE → HEAVY (FR Test #4)")


## AC-17: a crit on a LIGHT-ratio hit also overrides up to HEAVY.
func test_classify_tier_crit_overrides_light_to_heavy() -> void:
	# Arrange — 10/1000 = 0.01 → LIGHT without override.
	var tier = CombatResolver.classify_damage_tier(10, MAX_HP, true)

	# Assert
	assert_eq(tier, CombatResolver.DamageTier.HEAVY, "AC-17: crit forces LIGHT → HEAVY")


## AC-17: a crit on a MEDIUM-ratio hit overrides up to HEAVY.
func test_classify_tier_crit_overrides_medium_to_heavy() -> void:
	# Arrange — 50/1000 = 0.05 → MEDIUM without override.
	var tier = CombatResolver.classify_damage_tier(50, MAX_HP, true)

	# Assert
	assert_eq(tier, CombatResolver.DamageTier.HEAVY, "AC-17: crit forces MEDIUM → HEAVY")


## AC-17: a crit does NOT downgrade an already-CRITICAL tier (override is a floor).
func test_classify_tier_crit_does_not_downgrade_critical() -> void:
	# Arrange — 400/1000 = 0.40 → CRITICAL; crit must leave it CRITICAL (≥ HEAVY).
	var tier = CombatResolver.classify_damage_tier(400, MAX_HP, true)

	# Assert
	assert_eq(tier, CombatResolver.DamageTier.CRITICAL, "AC-17: crit override is a HEAVY floor, never a downgrade")


# ── AC-30: max_hp guard (no crash, no div-by-zero) ────────────────────────────

## AC-30: target_max_hp == 1 must not crash — any damage ≥ 1 yields pct ≥ 1.0 →
## CRITICAL (max(1, target_max_hp) guards the denominator).
func test_classify_tier_max_hp_1_yields_critical_no_crash() -> void:
	# Act — would div-by-zero if the guard were missing.
	var tier = CombatResolver.classify_damage_tier(1, 1, false)

	# Assert
	assert_eq(tier, CombatResolver.DamageTier.CRITICAL, "AC-30: max_hp=1, damage=1 → pct 1.0 → CRITICAL")


## AC-30: even target_max_hp == 0 (uninitialised) must not crash — max(1, 0) = 1.
## (resolve_hit gates max_hp==0 upstream via EC-08, but the pure function itself
## must remain crash-safe in isolation per FR Test #4 damage_tier-never-null.)
func test_classify_tier_max_hp_0_does_not_crash() -> void:
	# Act
	var tier = CombatResolver.classify_damage_tier(10, 0, false)

	# Assert — 10 / max(1, 0) = 10.0 → CRITICAL; the point is "no crash", tier defined.
	assert_eq(tier, CombatResolver.DamageTier.CRITICAL, "AC-30: max_hp=0 guarded by max(1,...) — no div-by-zero, tier defined")
