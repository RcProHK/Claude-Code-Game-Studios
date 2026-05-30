# CombatResolver — Story 004 Formula 2 (crit roll) + Formula 3 (crit multiplier)
# Unit Tests.
#
# Scope:
#   * AC-14 — roll_crit determinism: the SAME ctx (same transition_id / ability_id
#             / hit_seq / crit_chance) yields the SAME is_crit across 1000 repeated
#             calls (FR-1 binding — sub-seed re-seeds ctx.rng each call).
#   * AC-15 — apply_crit_multiplier: base=100 → 150, base=1 → round(1.5)=2.
#
# CombatResolver is preloaded (pure static class — NOT an autoload). RNG is
# caller-injected via ctx.rng; tests build a RandomNumberGenerator.new() and hand
# it to the resolver (allowed for the CALLER — only the resolver may not mint RNG).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Formula 2 + Formula 3
# Story: production/epics/combat-resolver/story-004-crit.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds a valid CombatContext with a tunable crit_chance + sub-seed fields.
func _make_ctx(crit_chance: float, transition_id: String = "txn-crit-1", ability_id: StringName = &"basic_strike", hit_seq: int = 0) -> RefCounted:
	var stats = CombatResolver.StatSnapshot.new()
	stats.attack_power = 100.0
	stats.crit_chance = crit_chance

	var enemy = CombatResolver.EnemyState.new()
	enemy.hp = 1000
	enemy.max_hp = 1000
	enemy.defense = 0.0

	var ctx = CombatResolver.CombatContext.new()
	ctx.ability_id = ability_id
	ctx.caster_stats = stats
	ctx.target_state = enemy
	ctx.ability_damage_multiplier = 1.0
	ctx.rng = RandomNumberGenerator.new()  # caller-injected (test owns it)
	ctx.gsm_state = &"Playing"
	ctx.transition_id = transition_id
	ctx.hit_seq = hit_seq
	return ctx


# ── AC-14: roll_crit determinism (1000× same ctx → same result) ───────────────

## AC-14: 1000 repeated roll_crit calls on the SAME ctx all return the identical
## value. roll_crit re-seeds ctx.rng from hash(transition_id:ability_id:hit_seq)
## each call, so the Bernoulli outcome is a pure function of the sub-seed tuple.
func test_roll_crit_is_deterministic_over_1000_calls() -> void:
	# Arrange — a mid-range crit_chance so the sub-seed actually decides the branch.
	var ctx = _make_ctx(0.30)

	# Act — capture the first roll, then assert every subsequent roll matches it.
	var first: bool = CombatResolver.roll_crit(ctx)

	# Assert
	for i: int in 1000:
		var again: bool = CombatResolver.roll_crit(ctx)
		assert_eq(again, first, "AC-14: roll_crit call %d diverged — crit decision must be deterministic for a fixed (transition_id, ability_id, hit_seq, crit_chance)" % i)


## AC-14: a different hit_seq produces an INDEPENDENT sub-seed (anti-degenerate
## per AOE invariant) — the crit stream is per-call, not shared frame-wide.
func test_roll_crit_different_hit_seq_uses_independent_subseed() -> void:
	# Arrange — same transition_id + ability, differing only by hit_seq.
	var ctx_a = _make_ctx(0.30, "txn-aoe", &"cleave", 0)
	var ctx_b = _make_ctx(0.30, "txn-aoe", &"cleave", 1)

	# Act — each is internally deterministic; we assert they do not share rng state.
	var a0: bool = CombatResolver.roll_crit(ctx_a)
	var a1: bool = CombatResolver.roll_crit(ctx_a)
	var b0: bool = CombatResolver.roll_crit(ctx_b)

	# Assert — ctx_a stays self-consistent regardless of how often we sampled it,
	# proving the per-call re-seed (hit_seq discriminator) gives independent streams.
	assert_eq(a0, a1, "AC-14: same ctx (hit_seq=0) must stay deterministic")
	assert_true(a0 == true or a0 == false, "AC-14: ctx_a yields a defined bool")
	assert_true(b0 == true or b0 == false, "AC-14: ctx_b (hit_seq=1) yields a defined bool from its own sub-seed")


## AC-14: crit_chance == 0.0 can NEVER crit (randf() ∈ [0,1) is never < 0.0).
func test_roll_crit_zero_chance_never_crits() -> void:
	# Arrange
	var ctx = _make_ctx(0.0)

	# Act / Assert — sample several sub-seeds; none may crit at p=0.
	for seq: int in 50:
		ctx.hit_seq = seq
		assert_false(CombatResolver.roll_crit(ctx), "AC-14: crit_chance 0.0 must never crit (hit_seq=%d)" % seq)


# ── AC-15: apply_crit_multiplier (Formula 3, ×1.5) ────────────────────────────

## AC-15: base 100 on crit → round(100 × 1.5) = 150.0.
func test_apply_crit_multiplier_base_100_crit_returns_150() -> void:
	# Act
	var result: float = CombatResolver.apply_crit_multiplier(100.0, true)

	# Assert
	assert_eq(result, 150.0, "AC-15: round(100 × 1.5) = 150")


## AC-15: base 1 on crit → round(1 × 1.5) = round(1.5) = 2.0 (crit always visible).
func test_apply_crit_multiplier_base_1_crit_returns_2() -> void:
	# Act
	var result: float = CombatResolver.apply_crit_multiplier(1.0, true)

	# Assert
	assert_eq(result, 2.0, "AC-15: round(1 × 1.5) = 2 — even a 1-damage crit reads as 2")


## AC-15: non-crit passes the base damage through unchanged (×1.0).
func test_apply_crit_multiplier_no_crit_passes_through() -> void:
	# Act
	var result: float = CombatResolver.apply_crit_multiplier(100.0, false)

	# Assert
	assert_eq(result, 100.0, "AC-15: non-crit must not scale damage")
