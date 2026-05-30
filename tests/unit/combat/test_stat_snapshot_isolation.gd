# CombatResolver — Story 006 AOE 1-to-1 Mapping Unit Tests (TR-combat-008).
#
# Scope:
#   * AC-11 — AOE 5-target mapping: a caller iterating resolve_hit with hit_seq
#             0..4 (same transition_id, same caster snapshot, distinct target_state)
#             produces 5 INDEPENDENT HitResult instances. Each hit_seq drives a
#             distinct roll_crit sub-seed (hash(transition_id:ability_id:hit_seq)),
#             so the crit streams do not lock-step. Order is preserved and no
#             shared mutable state leaks between successive resolve_hit calls.
#
# This is the "snapshot isolation across an AOE volley" test: one cast snapshot
# fans out to N targets and each target resolves on its own sub-seed.
#
# Determinism note (test-standards): sub-seeds are pure hashes of the ctx fields,
# so every assertion reproduces on every run.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Rule 14 (AOE); TR-combat-008
# Story: production/epics/combat-resolver/story-006-purity-snapshot-aoe.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds one AOE-target CombatContext. All targets in a volley share the same
## transition_id + caster snapshot; each gets a distinct hit_seq + target_state.
## crit_chance 0.5 so the per-target sub-seed actually swings the crit decision.
func _make_aoe_ctx(transition_id: String, hit_seq: int, target_instance_id: int) -> RefCounted:
	var stats = CombatResolver.StatSnapshot.new()
	stats.attack_power = 100.0
	stats.crit_chance = 0.5

	var enemy = CombatResolver.EnemyState.new()
	enemy.hp = 1000
	enemy.max_hp = 1000
	enemy.defense = 50.0
	enemy.instance_id = target_instance_id

	var ctx = CombatResolver.CombatContext.new()
	ctx.ability_id = &"cleave"
	ctx.caster_stats = stats
	ctx.target_state = enemy
	ctx.ability_damage_multiplier = 2.0
	ctx.rng = RandomNumberGenerator.new()
	ctx.gsm_state = &"Playing"
	ctx.transition_id = transition_id
	ctx.hit_seq = hit_seq
	return ctx


# ── AC-11: AOE 5-target 1-to-1 mapping ─────────────────────────────────────────

## AC-11: 5 targets → 5 distinct HitResult instances, returned in hit_seq order.
func test_aoe_five_targets_yield_five_distinct_results() -> void:
	# Arrange — one volley: same transition_id, hit_seq 0..4, 5 distinct targets.
	var results: Array = []

	# Act — caller iterates resolve_hit once per target (1-to-1 mapping).
	for i: int in 5:
		var ctx = _make_aoe_ctx("txn-aoe-volley", i, 500 + i)
		results.append(CombatResolver.resolve_hit(ctx))

	# Assert — 5 results, each a separate object instance (no shared reference).
	assert_eq(results.size(), 5, "AC-11: 5 targets → 5 HitResults (1-to-1 mapping)")
	for i: int in 5:
		assert_not_null(results[i], "AC-11: result #%d must be populated" % i)
		for j: int in range(i + 1, 5):
			assert_false(results[i] == results[j], "AC-11: result #%d and #%d must be distinct instances" % [i, j])


## AC-11: per-target hit_seq drives distinct crit sub-seeds — across the 5-target
## volley the crit decision is NOT uniform (the streams genuinely diverge by
## hit_seq, not a shared/global generator that would lock-step them).
func test_aoe_hit_seq_produces_independent_crit_streams() -> void:
	# Arrange — same transition_id, crit_chance 0.5; only hit_seq differs per target.
	# Sample a 16-target volley so the divergence is statistically visible while
	# staying deterministic (each sub-seed is a fixed hash).
	var saw_crit: bool = false
	var saw_no_crit: bool = false

	# Act
	for i: int in 16:
		var ctx = _make_aoe_ctx("txn-aoe-streams", i, 600 + i)
		var result = CombatResolver.resolve_hit(ctx)
		if result.is_crit:
			saw_crit = true
		else:
			saw_no_crit = true

	# Assert — both outcomes appear ⇒ hit_seq sub-seeds are independent streams.
	assert_true(saw_crit, "AC-11: at least one AOE target crits (hit_seq sub-seed independence)")
	assert_true(saw_no_crit, "AC-11: at least one AOE target does NOT crit (not all-crit lock-step)")


## AC-11: the AOE volley is order-stable and side-effect free — re-running the same
## 5-target volley reproduces the exact same per-index crit/damage sequence.
func test_aoe_volley_is_order_stable_and_reproducible() -> void:
	# Arrange — capture the first volley's per-index (is_crit, damage_dealt).
	var first_pass: Array = []
	for i: int in 5:
		var ctx = _make_aoe_ctx("txn-aoe-stable", i, 700 + i)
		var r = CombatResolver.resolve_hit(ctx)
		first_pass.append([r.is_crit, r.damage_dealt])

	# Act / Assert — a second identical volley must reproduce each index exactly.
	for i: int in 5:
		var ctx = _make_aoe_ctx("txn-aoe-stable", i, 700 + i)
		var r = CombatResolver.resolve_hit(ctx)
		assert_eq(r.is_crit, first_pass[i][0], "AC-11: target #%d crit reproduces across volleys" % i)
		assert_eq(r.damage_dealt, first_pass[i][1], "AC-11: target #%d damage reproduces across volleys" % i)


## AC-11: each target reads its OWN snapshot/target_state — no leakage between the
## successive resolve_hit calls (target instance_id isolation within one volley).
func test_aoe_each_target_resolves_against_its_own_state() -> void:
	# Arrange — 3 targets with DIFFERENT hp so their hp_after must differ.
	# defense 0, mult 1.0, attack 100, crit_chance 0 → deterministic 100 damage each.
	var hp_values: Array[int] = [120, 250, 90]
	var expected_hp_after: Array[int] = [20, 150, 0]  # 120-100, 250-100, max(0, 90-100)

	# Act / Assert
	for i: int in 3:
		var ctx = _make_aoe_ctx("txn-aoe-isolation", i, 800 + i)
		ctx.caster_stats.crit_chance = 0.0
		ctx.ability_damage_multiplier = 1.0
		ctx.target_state.defense = 0.0
		ctx.target_state.hp = hp_values[i]
		ctx.target_state.max_hp = 1000
		var r = CombatResolver.resolve_hit(ctx)
		assert_eq(r.target_hp_after, expected_hp_after[i], "AC-11: target #%d resolves against its OWN hp (no cross-target leakage)" % i)
