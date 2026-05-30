# CombatResolver — Story 005 Formula 5 (detect_overkill) Unit Tests.
#
# Scope:
#   * AC-18 — overkill: damage_raw 200 vs target_hp 50 → damage_dealt 50 (clamped),
#             overkill_excess 150, target_hp_after 0, is_kill true; resolve_hit
#             outcome = OVERKILL.
#   * AC-19 — exact kill: damage_raw 50 vs target_hp 50 → damage_dealt 50,
#             overkill_excess 0, is_kill true; resolve_hit outcome = KILLED
#             (exact-HP hit is a clean KILLED, not OVERKILL).
# Plus the conservation invariant (damage_dealt + target_hp_after == target_hp)
# and the non-lethal / min-1 floor cases.
#
# detect_overkill is the pure Formula-5 helper:
#   detect_overkill(damage_raw: float, target_hp: int) -> Dictionary
#   { damage_dealt, overkill_excess, target_hp_after, is_kill }
# resolve_hit assertions drive the helper through the full pipeline (crit_chance 0
# so roll_crit is always false → damage flows unscaled).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md Formula 5 (clamp + overflow)
# Story: production/epics/combat-resolver/story-005-tier-overkill.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")


## Builds a no-crit CombatContext that produces base_damage == `attack` (mult 1.0,
## defense 0). crit_chance 0.0 ⇒ roll_crit always false ⇒ damage flows unscaled.
func _make_ctx(attack: float, target_hp: int) -> RefCounted:
	var stats = CombatResolver.StatSnapshot.new()
	stats.attack_power = attack
	stats.crit_chance = 0.0

	var enemy = CombatResolver.EnemyState.new()
	enemy.hp = target_hp
	enemy.max_hp = 1000  # large denominator — tier is incidental to these overkill tests
	enemy.defense = 0.0

	var ctx = CombatResolver.CombatContext.new()
	ctx.ability_id = &"basic_strike"
	ctx.caster_stats = stats
	ctx.target_state = enemy
	ctx.ability_damage_multiplier = 1.0
	ctx.rng = RandomNumberGenerator.new()
	ctx.gsm_state = &"Playing"
	ctx.transition_id = "txn-overkill"
	ctx.hit_seq = 0
	return ctx


# ── AC-18: overkill (raw > hp) ────────────────────────────────────────────────

## AC-18: detect_overkill(200.0, 50) → clamp dealt at 50, expose 150 excess.
func test_detect_overkill_raw_200_hp_50_clamps_and_exposes_excess() -> void:
	# Act
	var info: Dictionary = CombatResolver.detect_overkill(200.0, 50)

	# Assert
	assert_eq(info["damage_dealt"], 50, "AC-18: damage_dealt clamps at target_hp (50)")
	assert_eq(info["overkill_excess"], 150, "AC-18: overkill_excess = 200 − 50 = 150")
	assert_eq(info["target_hp_after"], 0, "AC-18: target_hp_after clamps to 0")
	assert_true(info["is_kill"], "AC-18: 200 ≥ 50 → is_kill")


## AC-18: the full pipeline maps the overkill case to a OVERKILL outcome.
func test_resolve_hit_overkill_yields_overkill_outcome() -> void:
	# Arrange — base 200 vs 50 HP.
	var ctx = _make_ctx(200.0, 50)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_eq(result.damage_dealt, 50, "AC-18: resolve_hit clamps damage_dealt at 50")
	assert_eq(result.overkill_excess, 150, "AC-18: resolve_hit exposes 150 overkill_excess")
	assert_eq(result.target_hp_after, 0, "AC-18: hp_after 0")
	assert_true(result.is_kill, "AC-18: kill")
	assert_eq(result.outcome, CombatResolver.HitOutcome.OVERKILL, "AC-18: excess > 0 + kill → OVERKILL")


# ── AC-19: exact kill (raw == hp) ─────────────────────────────────────────────

## AC-19: detect_overkill(50.0, 50) → exact kill, zero excess.
func test_detect_overkill_raw_50_hp_50_is_exact_kill_zero_excess() -> void:
	# Act
	var info: Dictionary = CombatResolver.detect_overkill(50.0, 50)

	# Assert
	assert_eq(info["damage_dealt"], 50, "AC-19: damage_dealt = 50")
	assert_eq(info["overkill_excess"], 0, "AC-19: exact kill → 0 overkill_excess")
	assert_eq(info["target_hp_after"], 0, "AC-19: hp_after 0")
	assert_true(info["is_kill"], "AC-19: 50 ≥ 50 → is_kill")


## AC-19: the full pipeline maps the exact-kill case to KILLED (NOT OVERKILL).
func test_resolve_hit_exact_kill_yields_killed_outcome() -> void:
	# Arrange — base 50 vs 50 HP.
	var ctx = _make_ctx(50.0, 50)

	# Act
	var result = CombatResolver.resolve_hit(ctx)

	# Assert
	assert_eq(result.overkill_excess, 0, "AC-19: no overkill on an exact kill")
	assert_true(result.is_kill, "AC-19: kill")
	assert_eq(result.outcome, CombatResolver.HitOutcome.KILLED, "AC-19: exact kill (excess 0) → KILLED, not OVERKILL")


# ── Conservation + floor invariants (Formula 5 cross-knob) ────────────────────

## Conservation: a non-lethal hit preserves damage_dealt + target_hp_after == hp.
func test_detect_overkill_non_lethal_conserves_hp() -> void:
	# Act — 18 damage vs 50 HP.
	var info: Dictionary = CombatResolver.detect_overkill(18.0, 50)

	# Assert
	assert_eq(info["damage_dealt"], 18, "non-lethal: damage_dealt = 18")
	assert_eq(info["overkill_excess"], 0, "non-lethal: no excess")
	assert_eq(info["target_hp_after"], 32, "non-lethal: 50 − 18 = 32")
	assert_false(info["is_kill"], "non-lethal: 18 < 50 → no kill")
	assert_eq(info["damage_dealt"] + info["target_hp_after"], 50, "conservation: dealt + hp_after == target_hp")


## Min-1 floor: damage_raw rounds to 0 must still record at least 1 (anti tap-of-nothing).
func test_detect_overkill_sub_half_raw_floors_to_one() -> void:
	# Act — raw 0.4 rounds to 0, but the maxi(1, ...) floor records 1.
	var info: Dictionary = CombatResolver.detect_overkill(0.4, 50)

	# Assert
	assert_eq(info["damage_dealt"], 1, "min-1 floor: raw 0.4 → roundi 0 → maxi(1,0) = 1 damage")
	assert_eq(info["target_hp_after"], 49, "min-1 floor: 50 − 1 = 49")
	assert_false(info["is_kill"], "min-1 floor: 1 < 50 → no kill")
