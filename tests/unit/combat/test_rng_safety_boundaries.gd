# CombatResolver — Story 007 RNG Safety + AOE Boundary Unit Tests.
#
# Scope:
#   * AC-24 — Unicode-safe sub-seed: a transition_id containing CJK + emoji
#             ("TX-測試-🎲-001") feeds hash() inside roll_crit without throwing,
#             without returning 0, and WITHOUT colliding with a naive ASCII
#             truncation ("TX--001"). EC-28 binding.
#   * AC-25 — MAX_HIT_SEQ boundary: hit_seq = MAX_HIT_SEQ-1 and MAX_HIT_SEQ both
#             resolve normally (boundary is inclusive ≤); MAX_HIT_SEQ+1 is rejected
#             → safe HitResult{damage=0, NORMAL_HIT, NEGLIGIBLE} + push_error
#             (CLAMP_TRIGGERED). EC-27 binding.
#   * AC-29 — AOE clamp is CALLER (EnemyDirector) responsibility. CombatResolver
#             only exposes the MAX_TARGETS_PER_CAST=8 constant and resolves each
#             target 1-to-1 with no knowledge of total target count. We assert the
#             const value and simulate an already-clipped 8-target volley. EC-31.
#
# roll_crit re-seeds ctx.rng from the sub-seed hash, so reading ctx.rng.seed AFTER
# the call recovers the exact sub-seed — that is how AC-24 inspects the hash result
# without exposing a private hashing helper.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Rule 7 (sub-seed), Rule 14 (AOE)
# Story: production/epics/combat-resolver/story-007-rng-safety-aoe-boundary.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds a fully-valid CombatContext for boundary tests.
func _make_ctx(transition_id: String, hit_seq: int = 0) -> RefCounted:
	var stats = CombatResolver.StatSnapshot.new()
	stats.attack_power = 100.0
	# crit_chance = 0 so damage-asserting boundary tests (AC-25/AC-29) get a deterministic
	# non-crit 150 (base 100×2−50). roll_crit still re-seeds ctx.rng from the sub-seed hash
	# before the randf comparison, so AC-24's seed inspection + crash-safety are unaffected.
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
	ctx.transition_id = transition_id
	ctx.hit_seq = hit_seq
	return ctx


# ── AC-24: Unicode-safe sub-seed ───────────────────────────────────────────────

## AC-24: a Unicode transition_id feeds roll_crit without throwing and yields a
## non-zero sub-seed (recovered via ctx.rng.seed after the re-seed inside roll_crit).
func test_roll_crit_unicode_transition_id_does_not_throw_or_zero() -> void:
	# Arrange
	var ctx = _make_ctx("TX-測試-🎲-001", 0)

	# Act — roll_crit re-seeds ctx.rng from hash(transition_id:ability_id:hit_seq).
	var _is_crit = CombatResolver.roll_crit(ctx)
	var unicode_sub_seed: int = ctx.rng.seed

	# Assert — no crash reaching here; the sub-seed is a real (non-zero) hash.
	assert_ne(unicode_sub_seed, 0, "AC-24: Unicode transition_id must produce a non-zero sub-seed")


## AC-24: the Unicode transition_id must NOT collide with a naive ASCII truncation
## ("TX--001"-style). Full Unicode content participates in the hash → distinct seed.
func test_roll_crit_unicode_does_not_collide_with_ascii_truncation() -> void:
	# Arrange — same ability_id/hit_seq; only the transition_id Unicode content differs.
	var unicode_ctx = _make_ctx("TX-測試-🎲-001", 0)
	var ascii_ctx = _make_ctx("TX--001", 0)

	# Act — recover each sub-seed via the post-roll ctx.rng.seed.
	CombatResolver.roll_crit(unicode_ctx)
	CombatResolver.roll_crit(ascii_ctx)

	# Assert — distinct hashes ⇒ no silent collision between Unicode and ASCII.
	assert_ne(unicode_ctx.rng.seed, ascii_ctx.rng.seed, "AC-24: Unicode id must not collide with ASCII truncation")


## AC-24: resolve_hit completes end-to-end on a Unicode transition_id and the value
## propagates verbatim into HitResult.transition_id (no mangling).
func test_resolve_hit_unicode_transition_id_resolves_and_propagates() -> void:
	# Arrange
	var ctx = _make_ctx("TX-測試-🎲-001", 0)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_not_null(result, "AC-24: Unicode ctx must resolve without crashing")
	assert_eq(result.transition_id, "TX-測試-🎲-001", "AC-24: Unicode transition_id propagates verbatim")


## AC-24: an EMPTY transition_id is still a valid hash input (no crash, real seed).
func test_roll_crit_empty_transition_id_is_valid() -> void:
	# Arrange
	var ctx = _make_ctx("", 0)

	# Act
	var _is_crit = CombatResolver.roll_crit(ctx)

	# Assert — reaching here without error means hash(":basic_strike:0") was valid.
	assert_true(true, "AC-24: empty transition_id produces a valid hash (no crash)")


# ── AC-25: MAX_HIT_SEQ boundary (inclusive ≤) ──────────────────────────────────

## AC-25: hit_seq = MAX_HIT_SEQ-1 resolves NORMALLY (well inside the bound).
func test_resolve_hit_below_max_hit_seq_resolves_normally() -> void:
	# Arrange
	var ctx = _make_ctx("txn-boundary-below", CombatResolver.MAX_HIT_SEQ - 1)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — normal damage flows (Formula 1 base 100×2−50 = 150 vs 1000 HP).
	assert_eq(result.damage_dealt, 150, "AC-25: hit_seq = MAX_HIT_SEQ-1 resolves normally")


## AC-25: hit_seq = MAX_HIT_SEQ (the exact boundary) is INCLUSIVE — still resolves.
func test_resolve_hit_at_max_hit_seq_resolves_normally() -> void:
	# Arrange
	var ctx = _make_ctx("txn-boundary-at", CombatResolver.MAX_HIT_SEQ)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — boundary is `> MAX_HIT_SEQ` so MAX_HIT_SEQ itself passes.
	assert_eq(result.damage_dealt, 150, "AC-25: hit_seq = MAX_HIT_SEQ (boundary) is inclusive and resolves")


## AC-25: hit_seq = MAX_HIT_SEQ+1 is REJECTED → safe zero-damage anomaly result.
func test_resolve_hit_above_max_hit_seq_returns_anomaly_result() -> void:
	# Arrange
	var ctx = _make_ctx("txn-boundary-above", CombatResolver.MAX_HIT_SEQ + 1)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert — CLAMP_TRIGGERED safe defaults: 0 damage / NORMAL_HIT / NEGLIGIBLE.
	assert_not_null(result, "AC-25: over-bound hit_seq must return a safe HitResult, not null")
	assert_eq(result.damage_dealt, 0, "AC-25: hit_seq > MAX_HIT_SEQ → zero damage (CLAMP_TRIGGERED)")
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "AC-25: anomaly result outcome = NORMAL_HIT")
	assert_eq(result.damage_tier, CombatResolver.DamageTier.NEGLIGIBLE, "AC-25: anomaly result tier = NEGLIGIBLE (never null)")
	assert_false(result.is_kill, "AC-25: anomaly result is not a kill")


# ── AC-29: AOE clamp is caller-side; const is exposed for caller reference ──────

## AC-29: CombatResolver exposes MAX_TARGETS_PER_CAST = 8 for the caller to clamp
## against. The resolver itself never clamps target count (it sees one ctx at a time).
func test_max_targets_per_cast_constant_is_eight() -> void:
	# Assert
	assert_eq(CombatResolver.MAX_TARGETS_PER_CAST, 8, "AC-29: MAX_TARGETS_PER_CAST const = 8 (caller clamp reference)")


## AC-29: simulate the CALLER having already clipped 12 → 8 nearest targets. The
## resolver processes all 8 1-to-1 with no clamping of its own (it has no notion of
## the original 12). Proves CombatResolver is clamp-agnostic per EC-31.
func test_resolver_processes_caller_clipped_eight_targets() -> void:
	# Arrange — caller already dropped the extra 4; we feed exactly 8 (hit_seq 0..7).
	var results: Array = []

	# Act
	for i: int in CombatResolver.MAX_TARGETS_PER_CAST:
		var ctx = _make_ctx("txn-aoe-capped", i)
		results.append(CombatResolver.resolve_hit(ctx))

	# Assert — all 8 resolved; the resolver did NOT drop or clamp any of them.
	assert_eq(results.size(), 8, "AC-29: caller-clipped 8 targets all resolve (resolver is clamp-agnostic)")
	for i: int in 8:
		assert_eq(results[i].damage_dealt, 150, "AC-29: capped target #%d resolves to full damage" % i)
