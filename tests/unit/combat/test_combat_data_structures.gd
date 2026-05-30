# CombatResolver — Story 002 data structures (AC-21 / AC-07 / AC-09) Unit Tests.
#
# Scope: verifies the enum families and POD struct schemas declared inside
# src/core/combat_resolver.gd:
#   * AC-21 — HitOutcome is exactly 4 values, NORMAL_HIT=0 (ADR-0007 Family A safe default)
#   * AC-09 — AnomalyReason is exactly 6 values (combat-metric anomaly enum)
#   * AC-07 — HitResolvedPayload has exactly the 12 named fields, damage_tier never null
# Also smoke-checks DamageTier (5 values) and the EnemyKilledPayload round-trip
# (SerializableResource envelope, ADR-0006 Contract 3 / FR-2).
#
# CombatResolver is a `class_name ... extends RefCounted` pure static class — it
# is preloaded (NOT added as a child / autoload). Inner POD classes are reached
# via `CombatResolver.HitResult.new()` etc.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/combat-resolver.md; ADR-0007 (enum families); ADR-0006 C3
# Story: production/epics/combat-resolver/story-002-data-structures.md
extends GutTest

const CombatResolver := preload("res://src/core/combat_resolver.gd")
const EnemyKilledPayload := preload("res://src/core/enemy_killed_payload.gd")


# ── AC-21: HitOutcome enum ────────────────────────────────────────────────────

## AC-21: HitOutcome has exactly 4 values in canonical order, NORMAL_HIT=0.
func test_hit_outcome_enum_has_four_canonical_values() -> void:
	# Act
	var keys: Array = CombatResolver.HitOutcome.keys()
	var values: Array = CombatResolver.HitOutcome.values()

	# Assert
	assert_eq(values.size(), 4, "AC-21: HitOutcome must have exactly 4 values (DODGED absent — Rule 5)")
	assert_eq(keys, ["NORMAL_HIT", "CRITICAL_HIT", "KILLED", "OVERKILL"],
		"AC-21: HitOutcome canonical declaration order")
	assert_eq(int(CombatResolver.HitOutcome.NORMAL_HIT), 0,
		"AC-21: NORMAL_HIT must be ordinal 0 (ADR-0007 Family A safe default)")
	assert_eq(int(CombatResolver.HitOutcome.CRITICAL_HIT), 1, "AC-21: CRITICAL_HIT ordinal 1")
	assert_eq(int(CombatResolver.HitOutcome.KILLED), 2, "AC-21: KILLED ordinal 2")
	assert_eq(int(CombatResolver.HitOutcome.OVERKILL), 3, "AC-21: OVERKILL ordinal 3")


## AC-21: DODGED is NOT a HitOutcome member (Rule 5 — out of MVP scope).
func test_hit_outcome_has_no_dodged_member() -> void:
	assert_false(CombatResolver.HitOutcome.has("DODGED"),
		"AC-21: DODGED must NOT be a HitOutcome member (Rule 5 MVP scope)")


# ── AC-09: AnomalyReason enum ─────────────────────────────────────────────────

## AC-09: AnomalyReason has exactly 6 canonical values.
func test_anomaly_reason_enum_has_six_canonical_values() -> void:
	# Arrange
	const EXPECTED: Array[String] = [
		"GSM_SUSPENDED", "INVALID_ABILITY_ID", "NEGATIVE_DAMAGE",
		"CLAMP_TRIGGERED", "DEAD_TARGET_RESOLVE", "RNG_INJECTION_MISSING",
	]

	# Act
	var keys: Array = CombatResolver.AnomalyReason.keys()
	var values: Array = CombatResolver.AnomalyReason.values()

	# Assert
	assert_eq(values.size(), 6, "AC-09: AnomalyReason must have exactly 6 values")
	assert_eq(keys, EXPECTED, "AC-09: AnomalyReason canonical names + order")
	assert_eq(int(CombatResolver.AnomalyReason.GSM_SUSPENDED), 0,
		"AC-09: GSM_SUSPENDED ordinal 0 (Family A safe default)")


# ── DamageTier enum (Story 002 smoke) ─────────────────────────────────────────

## DamageTier has exactly 5 values, NEGLIGIBLE=0 (Family A safe default).
func test_damage_tier_enum_has_five_canonical_values() -> void:
	# Act
	var keys: Array = CombatResolver.DamageTier.keys()
	var values: Array = CombatResolver.DamageTier.values()

	# Assert
	assert_eq(values.size(), 5, "DamageTier must have exactly 5 values")
	assert_eq(keys, ["NEGLIGIBLE", "LIGHT", "MEDIUM", "HEAVY", "CRITICAL"],
		"DamageTier canonical declaration order")
	assert_eq(int(CombatResolver.DamageTier.NEGLIGIBLE), 0,
		"NEGLIGIBLE ordinal 0 (Family A safe default — damage_tier never null)")


# ── AC-07: HitResolvedPayload 12-field schema ─────────────────────────────────

## AC-07: HitResolvedPayload exposes exactly the 12 named fields.
func test_hit_resolved_payload_has_exactly_twelve_fields() -> void:
	# Arrange
	var payload = CombatResolver.HitResolvedPayload.new()
	const EXPECTED_FIELDS: Array[String] = [
		"ability_id", "caster_id", "target_id", "outcome", "damage_tier",
		"damage_dealt", "damage_raw", "target_hp_after", "is_crit", "is_kill",
		"transition_id", "resolved_at_tick",
	]

	# Act — collect SCRIPT_VARIABLE property names (exclude engine/built-in props).
	var found: Array[String] = []
	for prop: Dictionary in payload.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			found.append(String(prop["name"]))

	# Assert — all 12 present, and no extra script vars beyond the 12.
	for field_name: String in EXPECTED_FIELDS:
		assert_true(found.has(field_name),
			"AC-07: HitResolvedPayload must declare field '%s'" % field_name)
	assert_eq(found.size(), EXPECTED_FIELDS.size(),
		"AC-07: HitResolvedPayload must have EXACTLY 12 script fields (found: %s)" % str(found))


## AC-07: damage_tier defaults to NEGLIGIBLE (never null — FR Test #4).
func test_hit_resolved_payload_damage_tier_defaults_negligible() -> void:
	# Arrange
	var payload = CombatResolver.HitResolvedPayload.new()

	# Assert
	assert_eq(payload.damage_tier, CombatResolver.DamageTier.NEGLIGIBLE,
		"AC-07: damage_tier must default to NEGLIGIBLE, never null (FR Test #4)")
	assert_eq(payload.outcome, CombatResolver.HitOutcome.NORMAL_HIT,
		"AC-07: outcome must default to NORMAL_HIT (Family A safe default)")


# ── POD struct defaults smoke ─────────────────────────────────────────────────

## HitResult defaults are the safe-failure values (NORMAL_HIT / NEGLIGIBLE / 0).
func test_hit_result_defaults_are_safe() -> void:
	# Arrange
	var result = CombatResolver.HitResult.new()

	# Assert
	assert_eq(result.outcome, CombatResolver.HitOutcome.NORMAL_HIT, "HitResult.outcome default NORMAL_HIT")
	assert_eq(result.damage_tier, CombatResolver.DamageTier.NEGLIGIBLE, "HitResult.damage_tier default NEGLIGIBLE")
	assert_eq(result.damage_dealt, 0, "HitResult.damage_dealt default 0")
	assert_false(result.is_kill, "HitResult.is_kill default false")
	assert_false(result.is_crit, "HitResult.is_crit default false")


## EnemyState.max_hp defaults to 1 (not 0) so engagement-% never divides by zero.
func test_enemy_state_max_hp_defaults_to_one() -> void:
	# Arrange
	var state = CombatResolver.EnemyState.new()

	# Assert
	assert_eq(state.max_hp, 1, "EnemyState.max_hp must default to 1 (no divide-by-zero downstream)")
	assert_eq(state.hp, 0, "EnemyState.hp default 0")


# ── EnemyKilledPayload round-trip (ADR-0006 C3 / FR-2) ─────────────────────────

## EnemyKilledPayload survives a to_dict → from_dict round-trip with all fields.
func test_enemy_killed_payload_round_trip_preserves_fields() -> void:
	# Arrange
	var payload := EnemyKilledPayload.new()
	payload.enemy_id = &"goblin_grunt"
	payload.enemy_instance_id = 7
	payload.killer_id = 42
	payload.killing_ability = &"basic_strike"
	payload.transition_id = "txn-abc-123"
	payload.is_overkill = true
	payload.overkill_excess = 15

	# Act
	var as_dict: Dictionary = payload.to_dict()
	var restored = EnemyKilledPayload.from_dict(as_dict)

	# Assert — payload_type tag present + all fields survive.
	assert_eq(as_dict["payload_type"], "EnemyKilledPayload",
		"to_dict must tag payload_type via get_script().get_global_name()")
	assert_eq(restored.enemy_id, &"goblin_grunt", "enemy_id round-trips")
	assert_eq(restored.enemy_instance_id, 7, "enemy_instance_id round-trips")
	assert_eq(restored.killer_id, 42, "killer_id round-trips")
	assert_eq(restored.killing_ability, &"basic_strike", "killing_ability round-trips")
	assert_eq(restored.transition_id, "txn-abc-123", "transition_id round-trips")
	assert_true(restored.is_overkill, "is_overkill round-trips")
	assert_eq(restored.overkill_excess, 15, "overkill_excess round-trips")


## EnemyKilledPayload.from_dict is defensive against missing keys (safe defaults).
func test_enemy_killed_payload_from_dict_defends_missing_keys() -> void:
	# Act — empty dict (older schema / corrupt tombstone).
	var restored = EnemyKilledPayload.from_dict({})

	# Assert — every field falls back to its safe default.
	assert_eq(restored.enemy_id, &"", "missing enemy_id → empty StringName")
	assert_eq(restored.enemy_instance_id, 0, "missing enemy_instance_id → 0")
	assert_eq(restored.killer_id, 0, "missing killer_id → 0")
	assert_eq(restored.transition_id, "", "missing transition_id → empty String")
	assert_false(restored.is_overkill, "missing is_overkill → false")
	assert_eq(restored.overkill_excess, 0, "missing overkill_excess → 0")
