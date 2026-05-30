# CombatResolver — Story 004/007 replay-determinism Unit Tests (FR-1 binding).
#
# Scope:
#   * AC-22 — full resolve_hit replay: the SAME CombatContext resolved repeatedly
#             produces byte-identical HitResults (every field equal). This is the
#             FR-1 referential-transparency contract for the whole pipeline.
#   * AC-23 — transition_id drives the crit sub-seed: identical ctx EXCEPT
#             transition_id forms a DIFFERENT hash → independent crit streams.
#             Across many transition_ids the crit outcome varies (proving the
#             stream depends on transition_id, not a shared/global generator).
#
# Determinism note (test-standards): no wall-clock, no unseeded RNG — every roll
# is governed by the deterministic sub-seed hash(transition_id:ability_id:hit_seq),
# so these assertions are reproducible every run.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Formula 2 (FR-1); Rule 1 determinism
# Story: production/epics/combat-resolver/story-004-crit.md (AC-22 / AC-23)
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds a valid CombatContext. Crit-prone (crit_chance 0.5) so the crit branch
## actually exercises the sub-seed across transition_ids.
func _make_ctx(transition_id: String, hit_seq: int = 0) -> RefCounted:
	var stats = CombatResolver.StatSnapshot.new()
	stats.attack_power = 100.0
	stats.crit_chance = 0.5

	var enemy = CombatResolver.EnemyState.new()
	enemy.hp = 1000
	enemy.max_hp = 1000
	enemy.defense = 50.0

	var ctx = CombatResolver.CombatContext.new()
	ctx.ability_id = &"basic_strike"
	ctx.caster_stats = stats
	ctx.target_state = enemy
	ctx.ability_damage_multiplier = 2.0
	ctx.rng = RandomNumberGenerator.new()  # caller-injected
	ctx.gsm_state = &"Playing"
	ctx.transition_id = transition_id
	ctx.hit_seq = hit_seq
	return ctx


## Compares every HitResult field for byte-identical replay equality.
func _assert_results_identical(a: RefCounted, b: RefCounted, ctx_label: String) -> void:
	assert_eq(a.outcome, b.outcome, "%s: outcome must replay identically" % ctx_label)
	assert_eq(a.damage_tier, b.damage_tier, "%s: damage_tier must replay identically" % ctx_label)
	assert_eq(a.damage_dealt, b.damage_dealt, "%s: damage_dealt must replay identically" % ctx_label)
	assert_eq(a.damage_raw, b.damage_raw, "%s: damage_raw must replay identically" % ctx_label)
	assert_eq(a.target_hp_after, b.target_hp_after, "%s: target_hp_after must replay identically" % ctx_label)
	assert_eq(a.is_kill, b.is_kill, "%s: is_kill must replay identically" % ctx_label)
	assert_eq(a.overkill_excess, b.overkill_excess, "%s: overkill_excess must replay identically" % ctx_label)
	assert_eq(a.is_crit, b.is_crit, "%s: is_crit must replay identically" % ctx_label)
	assert_eq(a.ability_id, b.ability_id, "%s: ability_id must replay identically" % ctx_label)
	assert_eq(a.transition_id, b.transition_id, "%s: transition_id must replay identically" % ctx_label)


# ── AC-22: full resolve_hit replay determinism ────────────────────────────────

## AC-22: resolving the SAME ctx twice yields field-identical HitResults.
func test_resolve_hit_same_ctx_replays_identically() -> void:
	# Arrange
	var ctx = _make_ctx("txn-replay-A", 7)

	# Act
	var first = CombatResolver.resolve_hit(ctx)
	var second = CombatResolver.resolve_hit(ctx)

	# Assert
	_assert_results_identical(first, second, "AC-22 same-ctx replay")


## AC-22: two SEPARATELY-CONSTRUCTED ctx objects with identical field values
## resolve identically — determinism depends on data, not object identity.
func test_resolve_hit_equal_value_ctx_replays_identically() -> void:
	# Arrange — two distinct ctx instances, identical inputs (incl. transition_id).
	var ctx_a = _make_ctx("txn-replay-B", 3)
	var ctx_b = _make_ctx("txn-replay-B", 3)

	# Act
	var result_a = CombatResolver.resolve_hit(ctx_a)
	var result_b = CombatResolver.resolve_hit(ctx_b)

	# Assert
	_assert_results_identical(result_a, result_b, "AC-22 equal-value ctx")


## AC-22: many repeated resolves stay stable (no hidden accumulating state).
func test_resolve_hit_stable_over_many_replays() -> void:
	# Arrange
	var ctx = _make_ctx("txn-replay-C", 0)
	var baseline = CombatResolver.resolve_hit(ctx)

	# Act / Assert
	for i: int in 200:
		var again = CombatResolver.resolve_hit(ctx)
		_assert_results_identical(baseline, again, "AC-22 replay #%d" % i)


# ── AC-23: transition_id → different hash → independent crit streams ───────────

## AC-23: identical ctx except transition_id forms a different sub-seed hash, so
## the crit decision is drawn from an INDEPENDENT stream. Across many transition_ids
## the crit outcome must vary (some true, some false) — proving the stream is keyed
## on transition_id and not a shared/global generator that would lock-step them.
func test_resolve_hit_transition_id_yields_independent_crit_streams() -> void:
	# Arrange — 40 distinct transition_ids, everything else identical, crit_chance 0.5.
	var saw_crit: bool = false
	var saw_no_crit: bool = false

	# Act — sample the crit outcome across transition_ids.
	for i: int in 40:
		var ctx = _make_ctx("txn-stream-%d" % i, 0)
		var result = CombatResolver.resolve_hit(ctx)
		if result.is_crit:
			saw_crit = true
		else:
			saw_no_crit = true

	# Assert — both outcomes occur ⇒ streams genuinely diverge by transition_id.
	assert_true(saw_crit, "AC-23: at least one transition_id must crit (independent streams, not all-miss)")
	assert_true(saw_no_crit, "AC-23: at least one transition_id must NOT crit (independent streams, not all-crit)")


## AC-23: a fixed transition_id reproduces the SAME crit decision every time, even
## though different transition_ids diverge — determinism + independence together.
func test_resolve_hit_fixed_transition_id_is_reproducible() -> void:
	# Arrange / Act — resolve the same transition_id across 3 fresh ctx objects.
	var crit_1 = CombatResolver.resolve_hit(_make_ctx("txn-fixed", 0)).is_crit
	var crit_2 = CombatResolver.resolve_hit(_make_ctx("txn-fixed", 0)).is_crit
	var crit_3 = CombatResolver.resolve_hit(_make_ctx("txn-fixed", 0)).is_crit

	# Assert
	assert_eq(crit_1, crit_2, "AC-23: fixed transition_id must reproduce the same crit decision")
	assert_eq(crit_2, crit_3, "AC-23: fixed transition_id must reproduce the same crit decision")
