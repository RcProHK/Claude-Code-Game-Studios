# CombatResolver — Story 008 Defensive Guards Unit Tests (TR-combat-017).
#
# Scope:
#   * AC-26 — null ctx: resolve_hit(null) returns a safe HitResult
#             {damage=0, NORMAL_HIT, NEGLIGIBLE} + push_error, never crashes.
#             EC-01 binding.
#   * AC-27 — dead target (hp == 0): returns damage=0 with outcome NORMAL_HIT
#             (NOT KILLED — the target was already dead, not a combat kill).
#             EC-06 binding.
#   * AC-28 — NaN / INF ability_damage_multiplier: caught in Stage 1 BEFORE any
#             math → safe zero result + push_error (INVALID_ABILITY_ID). No NaN/INF
#             ever propagates into HitResult fields. EC-12 binding.
#
# These tests exercise the Stage-1 reject paths only; the nominal pipeline is
# covered by test_formula1_base_damage.gd and test_combat_resolver_determinism.gd.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Rule 4 (Stage 1); EC-01/EC-06/EC-12
# Story: production/epics/combat-resolver/story-008-defensive-guards.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds a fully-valid CombatContext (the caller mutates one field per test to
## drive a single guard in isolation).
func _make_ctx() -> RefCounted:
	var stats = CombatResolver.StatSnapshot.new()
	stats.attack_power = 100.0
	stats.crit_chance = 0.0

	var enemy = CombatResolver.EnemyState.new()
	enemy.hp = 1000
	enemy.max_hp = 1000
	enemy.defense = 50.0

	var ctx = CombatResolver.CombatContext.new()
	ctx.ability_id = &"basic_strike"
	ctx.caster_stats = stats
	ctx.target_state = enemy
	ctx.ability_damage_multiplier = 2.0
	ctx.rng = RandomNumberGenerator.new()
	ctx.gsm_state = &"Playing"
	ctx.transition_id = "txn-guard"
	return ctx


# ── AC-26: null ctx safe return ────────────────────────────────────────────────

## AC-26: resolve_hit(null) returns safe defaults and does not crash.
func test_resolve_hit_null_ctx_returns_safe_negligible_result() -> void:
	# Act
	var result = CombatResolver.resolve_hit(null)

	# Assert
	assert_not_null(result, "AC-26: null ctx must return a safe HitResult, not null")
	assert_eq(result.damage_dealt, 0, "AC-26: null ctx → zero damage")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "AC-26: null ctx → NORMAL_HIT")
	assert_eq(result.damage_tier, CombatResolver.DamageTier.NEGLIGIBLE, "AC-26: null ctx → NEGLIGIBLE tier (never null)")
	assert_false(result.is_kill, "AC-26: null ctx → not a kill")


## AC-26: repeated null calls are each independently safe (no accumulating state).
func test_resolve_hit_null_ctx_is_repeatably_safe() -> void:
	# Act / Assert — 5 consecutive null calls, each must return a safe result.
	for i: int in 5:
		var result = CombatResolver.resolve_hit(null)
		assert_eq(result.damage_dealt, 0, "AC-26: null call #%d stays safe (zero damage)" % i)


# ── AC-27: dead target safe return (NORMAL_HIT, not KILLED) ─────────────────────

## AC-27: ctx.target_state.hp == 0 → zero damage, outcome NORMAL_HIT (NOT KILLED).
## The target was already dead, so no kill event should fire.
func test_resolve_hit_dead_target_returns_normal_hit_zero_damage() -> void:
	# Arrange
	var ctx = _make_ctx()
	ctx.target_state.hp = 0

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_eq(result.damage_dealt, 0, "AC-27: dead target (hp=0) → zero damage")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "AC-27: dead target → NORMAL_HIT, NOT KILLED")
	assert_false(result.is_kill, "AC-27: dead target → is_kill false (not a combat kill)")
	assert_ne(result.outcome, CombatResolver.HitOutcome.KILLED, "AC-27: outcome must NOT be KILLED for an already-dead target")


## AC-27: negative hp (over-killed in a prior frame) is also treated as dead.
func test_resolve_hit_negative_hp_target_returns_normal_hit_zero_damage() -> void:
	# Arrange
	var ctx = _make_ctx()
	ctx.target_state.hp = -5

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — gate is `hp <= 0`, so negative hp also rejects safely.
	assert_eq(result.damage_dealt, 0, "AC-27: negative-hp target → zero damage")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "AC-27: negative-hp target → NORMAL_HIT")


# ── AC-28: NaN / INF multiplier reject (caught in Stage 1, no propagation) ──────

## AC-28: NaN ability_damage_multiplier is rejected in Stage 1 → safe zero result
## with NO NaN leaking into any HitResult field.
func test_resolve_hit_nan_multiplier_returns_safe_result_no_nan_leak() -> void:
	# Arrange
	var ctx = _make_ctx()
	ctx.ability_damage_multiplier = NAN

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — zero damage, NORMAL_HIT, and damage_raw is finite (not NaN).
	assert_eq(result.damage_dealt, 0, "AC-28: NaN multiplier → zero damage")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "AC-28: NaN multiplier → NORMAL_HIT")
	assert_eq(result.damage_tier, CombatResolver.DamageTier.NEGLIGIBLE, "AC-28: NaN multiplier → NEGLIGIBLE tier")
	assert_false(is_nan(result.damage_raw), "AC-28: damage_raw must NOT be NaN (no propagation through pipeline)")
	assert_eq(result.damage_raw, 0.0, "AC-28: NaN multiplier → damage_raw is a clean 0.0")


## AC-28: positive INF multiplier is rejected by the same is_inf guard.
func test_resolve_hit_positive_inf_multiplier_returns_safe_result() -> void:
	# Arrange
	var ctx = _make_ctx()
	ctx.ability_damage_multiplier = INF

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — no INF leaks; safe zero result.
	assert_eq(result.damage_dealt, 0, "AC-28: +INF multiplier → zero damage")
	assert_false(is_inf(result.damage_raw), "AC-28: damage_raw must NOT be INF")
	assert_eq(result.damage_raw, 0.0, "AC-28: +INF multiplier → damage_raw is a clean 0.0")


## AC-28: negative INF multiplier is also rejected (is_inf catches ±INF).
func test_resolve_hit_negative_inf_multiplier_returns_safe_result() -> void:
	# Arrange
	var ctx = _make_ctx()
	ctx.ability_damage_multiplier = -INF

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_eq(result.damage_dealt, 0, "AC-28: -INF multiplier → zero damage")
	assert_false(is_inf(result.damage_raw), "AC-28: damage_raw must NOT be -INF")


## AC-28: the NaN guard fires AHEAD of the dead-target gate — a ctx that is BOTH
## NaN-multiplier and dead still returns the safe defaults (observable result is
## identical: zero damage / NORMAL_HIT), confirming the gate ordering is harmless.
func test_resolve_hit_nan_multiplier_with_dead_target_still_safe() -> void:
	# Arrange — both anomalies present at once.
	var ctx = _make_ctx()
	ctx.ability_damage_multiplier = NAN
	ctx.target_state.hp = 0

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — observable safe result regardless of which gate fired first.
	assert_eq(result.damage_dealt, 0, "AC-28: NaN + dead target → zero damage")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "AC-28: NaN + dead target → NORMAL_HIT")
	assert_false(is_nan(result.damage_raw), "AC-28: damage_raw stays finite even with both anomalies")
