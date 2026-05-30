# CombatResolver — Story 003 Formula 1 base damage + 5-stage pipeline Unit Tests.
#
# Scope:
#   * AC-12 — compute_hit_damage nominal: attack=100, mult=2.0, defense=50 → 150
#   * AC-13 — compute_hit_damage floor clamp: result would be negative → 1
#   * AC-20 — resolve_hit runs the full 5-stage pipeline and returns a populated
#             HitResult (validation gates → Formula 1 → crit → multiplier →
#             overkill/tier → outcome), with no stage skipped.
# Plus the Stage-1 validation gates (null ctx / dead target / GSM suspended /
# missing rng) each return a safe default HitResult rather than null.
#
# CombatResolver is preloaded (pure static class — NOT an autoload). Static
# methods are called as `CombatResolver.compute_hit_damage(ctx)` /
# `CombatResolver.resolve_hit(ctx)`. Inner POD structs via `CombatResolver.X.new()`.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Formula 1 + Rule 4; ADR-0006 C12
# Story: production/epics/combat-resolver/story-003-formula1-pipeline.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds a fully-valid CombatContext for the nominal/pipeline paths.
func _make_ctx(attack: float, multiplier: float, defense: float, target_hp: int = 1000, target_max_hp: int = 1000) -> RefCounted:
	var stats = CombatResolver.StatSnapshot.new()
	stats.attack_power = attack
	stats.crit_chance = 0.0

	var enemy = CombatResolver.EnemyState.new()
	enemy.hp = target_hp
	enemy.max_hp = target_max_hp
	enemy.defense = defense

	var ctx = CombatResolver.CombatContext.new()
	ctx.ability_id = &"basic_strike"
	ctx.caster_stats = stats
	ctx.target_state = enemy
	ctx.ability_damage_multiplier = multiplier
	ctx.rng = RandomNumberGenerator.new()  # injected by the CALLER (test) — allowed; only the resolver may not mint RNG
	ctx.gsm_state = &"Playing"
	ctx.transition_id = "txn-test-1"
	return ctx


# ── AC-12: Formula 1 nominal path ─────────────────────────────────────────────

## AC-12: attack=100, mult=2.0, defense=50 → maxi(1, round(150)) == 150.
func test_compute_hit_damage_nominal_returns_150() -> void:
	# Arrange
	var ctx = _make_ctx(100.0, 2.0, 50.0)

	# Act
	var damage: int = CombatResolver.compute_hit_damage(ctx)

	# Assert
	assert_eq(damage, 150, "AC-12: Formula 1 nominal — 100×2.0−50 = 150")


## AC-12 edge: attack=50, mult=3.0, defense=50 → round(100) == 100.
func test_compute_hit_damage_edge_returns_100() -> void:
	# Arrange
	var ctx = _make_ctx(50.0, 3.0, 50.0)

	# Act
	var damage: int = CombatResolver.compute_hit_damage(ctx)

	# Assert
	assert_eq(damage, 100, "AC-12 edge: 50×3.0−50 = 100")


# ── AC-13: Floor clamp (guaranteed hit) ───────────────────────────────────────

## AC-13: attack=10, mult=1.0, defense=100 (raw −90) → maxi(1, ...) == 1.
func test_compute_hit_damage_floor_clamps_to_one() -> void:
	# Arrange
	var ctx = _make_ctx(10.0, 1.0, 100.0)

	# Act
	var damage: int = CombatResolver.compute_hit_damage(ctx)

	# Assert
	assert_eq(damage, 1, "AC-13: negative raw must clamp to 1 (guaranteed hit), not 0/negative")


## AC-13 edge: attack×mult == defense exactly (raw 0) → maxi(1, 0) == 1.
func test_compute_hit_damage_zero_raw_clamps_to_one() -> void:
	# Arrange
	var ctx = _make_ctx(50.0, 1.0, 50.0)

	# Act
	var damage: int = CombatResolver.compute_hit_damage(ctx)

	# Assert
	assert_eq(damage, 1, "AC-13 edge: raw 0 → maxi(1, 0) = 1")


# ── AC-20: 5-stage pipeline ───────────────────────────────────────────────────

## AC-20: resolve_hit returns a fully-populated HitResult (no stage skipped).
## damage_dealt == Formula-1 base (no crit in Batch A), outcome derived, tier set.
func test_resolve_hit_runs_full_pipeline_and_populates_result() -> void:
	# Arrange — base damage = 100×2.0−50 = 150 against a 1000-HP target.
	var ctx = _make_ctx(100.0, 2.0, 50.0, 1000, 1000)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — Stage 2 base damage flowed through; Batch A has no crit.
	assert_not_null(result, "AC-20: resolve_hit must never return null")
	assert_eq(result.damage_dealt, 150, "AC-20: damage_dealt = Formula-1 base (no crit in Batch A)")
	assert_eq(result.damage_raw, 150.0, "AC-20: damage_raw carries the pre-multiplier base")
	assert_false(result.is_crit, "AC-20: Batch A roll_crit stub yields no crit")
	assert_false(result.is_kill, "AC-20: 150 dmg vs 1000 HP is not a kill")
	assert_eq(result.target_hp_after, 850, "AC-20: target_hp_after = 1000 − 150")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "AC-20: non-crit non-kill → NORMAL_HIT")
	assert_eq(result.ability_id, &"basic_strike", "AC-20: ability_id propagated from ctx")
	assert_eq(result.transition_id, "txn-test-1", "AC-20: transition_id propagated from ctx")


## AC-20: a lethal hit drives the pipeline to a KILLED outcome with hp_after 0.
func test_resolve_hit_lethal_hit_yields_killed_outcome() -> void:
	# Arrange — 150 damage vs a 100-HP target → kill, 50 overkill.
	var ctx = _make_ctx(100.0, 2.0, 50.0, 100, 100)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_true(result.is_kill, "AC-20: 150 dmg vs 100 HP is a kill")
	assert_eq(result.target_hp_after, 0, "AC-20: hp_after clamps to 0 on a kill")
	assert_eq(result.overkill_excess, 50, "AC-20: 150−100 = 50 overkill excess")
	assert_eq(result.outcome, CombatResolver.HitOutcome.OVERKILL, "AC-20: kill with excess → OVERKILL")


# ── Stage-1 validation gates (Story 003 helpers) ──────────────────────────────

## Null ctx returns a safe default HitResult (never null).
func test_resolve_hit_null_ctx_returns_safe_result() -> void:
	# Act
	var result = CombatResolver.resolve_hit(null)

	# Assert
	assert_not_null(result, "null ctx must return a safe HitResult, not null")
	assert_eq(result.damage_dealt, 0, "null ctx → zero damage")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "null ctx → NORMAL_HIT default")


## Dead target (hp <= 0) returns a safe zero-damage result before any math.
func test_resolve_hit_dead_target_returns_safe_result() -> void:
	# Arrange
	var ctx = _make_ctx(100.0, 2.0, 50.0, 0, 100)  # hp = 0

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_eq(result.damage_dealt, 0, "dead target → zero damage (gate fires before Formula 1)")
	assert_false(result.is_kill, "dead target → no kill")


## GSM Suspended returns a safe zero-damage result.
func test_resolve_hit_gsm_suspended_returns_safe_result() -> void:
	# Arrange
	var ctx = _make_ctx(100.0, 2.0, 50.0)
	ctx.gsm_state = &"Suspended"

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_eq(result.damage_dealt, 0, "GSM Suspended → zero damage (no combat while suspended)")


## Missing injected RNG returns a safe result (FR-1 — RNG must be caller-injected).
func test_resolve_hit_missing_rng_returns_safe_result() -> void:
	# Arrange
	var ctx = _make_ctx(100.0, 2.0, 50.0)
	ctx.rng = null

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_eq(result.damage_dealt, 0, "missing ctx.rng → zero damage (FR-1 injection guard)")
