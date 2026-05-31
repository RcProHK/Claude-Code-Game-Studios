# EnemyDirector — Story 005 AC-08: Signal Payload Schema Verification
#
# Coverage:
#   AC-08 — HitResolvedPayload / EnemyKilledPayload / CombatAnomalyPayload
#     field names + types verified; payloads extend correct base class.
#   Payloads are ground-truth implementations already in src/core/ —
#   this test locks the schema so breaking changes are caught immediately.
extends GutTest


# ---------------------------------------------------------------------------
# HitResolvedPayload (inner class of CombatResolver — src/core/combat_resolver.gd)
# ---------------------------------------------------------------------------

## Full 12-field schema lock via default-value assertions (locks both presence AND type).
## assert_eq against defaults catches a field deleted, renamed, OR silently retyped —
## stronger than assert_not_null. Source of truth: combat_resolver.gd:161-173.
func test_ac08_hit_resolved_payload_fields_present() -> void:
	# Arrange — access via CombatResolver's inner class namespace.
	var payload := CombatResolver.HitResolvedPayload.new()
	# Assert all 12 fields by default value (type-locking).
	assert_eq(payload.ability_id, &"", "AC-08: ability_id default empty StringName")
	assert_eq(payload.caster_id, 0, "AC-08: caster_id default 0")
	assert_eq(payload.target_id, 0, "AC-08: target_id default 0")
	assert_eq(payload.outcome, CombatResolver.HitOutcome.NORMAL_HIT,
		"AC-08: outcome default NORMAL_HIT (Family A ordinal 0)")
	# damage_tier carries the "NEVER null" invariant (FR Test #4) — lock its default.
	assert_eq(payload.damage_tier, CombatResolver.DamageTier.NEGLIGIBLE,
		"AC-08: damage_tier default NEGLIGIBLE — NEVER null invariant (combat_resolver.gd:166)")
	assert_eq(payload.damage_dealt, 0, "AC-08: damage_dealt default 0 (int)")
	assert_eq(payload.damage_raw, 0.0, "AC-08: damage_raw default 0.0 (float)")
	assert_eq(payload.target_hp_after, 0, "AC-08: target_hp_after default 0")
	assert_eq(payload.is_crit, false, "AC-08: is_crit default false")
	assert_eq(payload.is_kill, false, "AC-08: is_kill default false")
	assert_eq(payload.transition_id, "", "AC-08: transition_id default empty String (ADR-0005 chain)")
	assert_eq(payload.resolved_at_tick, 0, "AC-08: resolved_at_tick default 0")


## transition_id must default to empty string (used as RNG seed — must be non-null).
func test_ac08_hit_resolved_transition_id_default() -> void:
	var payload := CombatResolver.HitResolvedPayload.new()
	assert_eq(payload.transition_id, "",
		"AC-08: HitResolvedPayload.transition_id must default to empty string (never null)")


# ---------------------------------------------------------------------------
# EnemyKilledPayload (src/core/enemy_killed_payload.gd)
# ---------------------------------------------------------------------------

func test_ac08_enemy_killed_payload_has_transition_id() -> void:
	var payload := EnemyKilledPayload.new()
	# transition_id is the ADR-0005 chain seed for #15 LootDrop RNG.
	assert_not_null(payload.get("transition_id"),
		"AC-08: EnemyKilledPayload.transition_id must be present (ADR-0005 FR-2 chain)")
	assert_eq(payload.transition_id, "",
		"AC-08: EnemyKilledPayload.transition_id must default to empty string")


func test_ac08_enemy_killed_payload_has_enemy_instance_id() -> void:
	var payload := EnemyKilledPayload.new()
	assert_not_null(payload.get("enemy_instance_id"),
		"AC-08: EnemyKilledPayload.enemy_instance_id must be present")


# ---------------------------------------------------------------------------
# CombatAnomalyPayload (src/core/combat_anomaly_payload.gd — NEW in Story 005)
# ---------------------------------------------------------------------------

func test_ac08_combat_anomaly_payload_extends_ref_counted() -> void:
	var payload := CombatAnomalyPayload.new()
	assert_is(payload, RefCounted,
		"AC-08: CombatAnomalyPayload must extend RefCounted (transient event, not persisted)")


func test_ac08_combat_anomaly_payload_fields_correct() -> void:
	var payload := CombatAnomalyPayload.new()
	# reason: StringName default empty
	assert_eq(payload.reason, &"",
		"AC-08: CombatAnomalyPayload.reason must default to empty StringName")
	# aggregate: bool default false
	assert_eq(payload.aggregate, false,
		"AC-08: CombatAnomalyPayload.aggregate must default to false")
	# dropped_count: int default 0
	assert_eq(payload.dropped_count, 0,
		"AC-08: CombatAnomalyPayload.dropped_count must default to 0")
	# context_dump: Dictionary default empty
	assert_true(payload.context_dump.is_empty(),
		"AC-08: CombatAnomalyPayload.context_dump must default to empty Dictionary")


func test_ac08_combat_anomaly_payload_fields_settable() -> void:
	var payload := CombatAnomalyPayload.new()
	payload.reason = &"GSM_SUSPENDED"
	payload.aggregate = true
	payload.dropped_count = 42
	payload.context_dump = {"ability_id": "STRIKE_1"}
	assert_eq(payload.reason, &"GSM_SUSPENDED", "AC-08: reason settable")
	assert_eq(payload.aggregate, true, "AC-08: aggregate settable")
	assert_eq(payload.dropped_count, 42, "AC-08: dropped_count settable")
	assert_eq(payload.context_dump.size(), 1, "AC-08: context_dump settable")
