# CombatResolver — Story 006 Stateless Purity Unit Tests (TR-combat-002/003).
#
# Scope:
#   * AC-02 — 1000-run determinism: the SAME CombatContext resolved 1000 times
#             yields field-for-field identical HitResults. Proves resolve_hit is a
#             pure function with no hidden accumulating state.
#   * AC-03 — instance vs static equivalence: calling resolve_hit through a
#             `CombatResolver.new()` instance produces the same result as a bare
#             static call. static func carries NO instance state (cannot touch self).
#   * AC-04 — StatSnapshot isolation: resolve_hit reads ONLY ctx.caster_stats; a
#             mid-call mutation to a separate mock source does NOT propagate into
#             the damage figure (the snapshot value is authoritative).
#
# Determinism note (test-standards): every roll is governed by the deterministic
# sub-seed hash(transition_id:ability_id:hit_seq) inside roll_crit, so these
# assertions reproduce identically on every run — no wall-clock, no unseeded RNG.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Rules 1/2/6; TR-combat-002/003
# Story: production/epics/combat-resolver/story-006-purity-snapshot-aoe.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds a fully-valid, crit-prone CombatContext (crit_chance 0.5 exercises the
## crit branch). target_hp high enough that the hit is never a kill, so every
## HitResult field (incl. overkill/hp_after) stays in the nominal range.
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
	ctx.rng = RandomNumberGenerator.new()  # caller-injected (test allowed)
	ctx.gsm_state = &"Playing"
	ctx.transition_id = transition_id
	ctx.hit_seq = hit_seq
	return ctx


## Compares every HitResult field for byte-identical purity equality.
func _assert_results_identical(a: RefCounted, b: RefCounted, ctx_label: String) -> void:
	assert_eq(a.outcome, b.outcome, "%s: outcome identical" % ctx_label)
	assert_eq(a.damage_tier, b.damage_tier, "%s: damage_tier identical" % ctx_label)
	assert_eq(a.damage_dealt, b.damage_dealt, "%s: damage_dealt identical" % ctx_label)
	assert_eq(a.damage_raw, b.damage_raw, "%s: damage_raw identical" % ctx_label)
	assert_eq(a.target_hp_after, b.target_hp_after, "%s: target_hp_after identical" % ctx_label)
	assert_eq(a.is_kill, b.is_kill, "%s: is_kill identical" % ctx_label)
	assert_eq(a.overkill_excess, b.overkill_excess, "%s: overkill_excess identical" % ctx_label)
	assert_eq(a.is_crit, b.is_crit, "%s: is_crit identical" % ctx_label)
	assert_eq(a.ability_id, b.ability_id, "%s: ability_id identical" % ctx_label)
	assert_eq(a.transition_id, b.transition_id, "%s: transition_id identical" % ctx_label)


# ── AC-02: 1000-run determinism (pure function, no accumulating state) ─────────

## AC-02: resolving ONE ctx 1000 times produces field-identical HitResults.
## roll_crit re-seeds ctx.rng from the sub-seed each call, so no RNG state leaks
## between calls — the result is governed purely by the ctx data.
func test_resolve_hit_1000_runs_are_field_identical() -> void:
	# Arrange
	var ctx = _make_ctx("txn-purity-1000", 11)
	var baseline = CombatResolver.resolve_hit(ctx)

	# Act / Assert — 1000 repeats must all match the baseline exactly.
	for i: int in 1000:
		var again = CombatResolver.resolve_hit(ctx)
		_assert_results_identical(baseline, again, "AC-02 run #%d" % i)


## AC-02: 1000 SEPARATELY-CONSTRUCTED but equal-valued ctx objects also resolve
## identically — purity depends on data, not object identity or a warmed-up cache.
func test_resolve_hit_1000_fresh_ctx_are_field_identical() -> void:
	# Arrange
	var baseline = CombatResolver.resolve_hit(_make_ctx("txn-purity-fresh", 4))

	# Act / Assert
	for i: int in 1000:
		var fresh = CombatResolver.resolve_hit(_make_ctx("txn-purity-fresh", 4))
		_assert_results_identical(baseline, fresh, "AC-02 fresh-ctx #%d" % i)


# ── AC-03: instance vs static equivalence (no instance state) ──────────────────

## AC-03: calling resolve_hit via a CombatResolver.new() instance equals the bare
## static call. static func cannot reference self → no instance contamination.
func test_resolve_hit_instance_call_equals_static_call() -> void:
	# Arrange
	var resolver = CombatResolver.new()
	var static_result = CombatResolver.resolve_hit(_make_ctx("txn-inst-eq", 2))

	# Act — both calls routed through the same instance, plus a fresh static call.
	var inst_result_a = resolver.resolve_hit(_make_ctx("txn-inst-eq", 2))
	var inst_result_b = resolver.resolve_hit(_make_ctx("txn-inst-eq", 2))

	# Assert — instance calls match each other AND the static call.
	_assert_results_identical(inst_result_a, inst_result_b, "AC-03 instance self-consistency")
	_assert_results_identical(inst_result_a, static_result, "AC-03 instance vs static")


## AC-03: resolving an UNRELATED ctx on the instance between two identical calls
## leaves no residue — the third call still matches the first (no state carried).
func test_resolve_hit_instance_interleaved_call_leaves_no_state() -> void:
	# Arrange
	var resolver = CombatResolver.new()

	# Act — call A, then an unrelated B, then A again on the SAME instance.
	var first_a = resolver.resolve_hit(_make_ctx("txn-A", 0))
	var _unrelated_b = resolver.resolve_hit(_make_ctx("txn-B", 99))
	var second_a = resolver.resolve_hit(_make_ctx("txn-A", 0))

	# Assert — B did not contaminate A.
	_assert_results_identical(first_a, second_a, "AC-03 interleaved no-state")


# ── AC-04: StatSnapshot isolation from mid-call source mutation ────────────────

## AC-04: resolve_hit reads ONLY ctx.caster_stats.attack_power. Mutating a SEPARATE
## mock source object (simulating a concurrent StatSystem change) does NOT change
## the damage — the snapshot value (100) is authoritative, not the live source (999).
func test_resolve_hit_uses_snapshot_not_mutated_source() -> void:
	# Arrange — snapshot captured at attack_power = 100; defense 0 so damage maps
	# cleanly: 100 × 1.0 − 0 = 100. crit_chance 0 → deterministic non-crit.
	var ctx = _make_ctx("txn-snapshot", 0)
	ctx.caster_stats.attack_power = 100.0
	ctx.caster_stats.crit_chance = 0.0
	ctx.ability_damage_multiplier = 1.0
	ctx.target_state.defense = 0.0

	# A separate "live source" that a concurrent system might mutate. The resolver
	# never reads this — it only reads ctx.caster_stats.
	var mock_source = CombatResolver.StatSnapshot.new()
	mock_source.attack_power = 100.0

	# Act — mutate the live source to 999 BEFORE resolving. The snapshot on ctx is
	# unaffected (value-copied struct; resolver never dereferences mock_source).
	mock_source.attack_power = 999.0
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — damage reflects the snapshot 100, NOT the mutated source 999.
	assert_eq(result.damage_dealt, 100, "AC-04: damage uses snapshot attack_power=100, not mutated source=999")
	assert_eq(ctx.caster_stats.attack_power, 100.0, "AC-04: ctx snapshot stays 100 (source mutation does not leak in)")
