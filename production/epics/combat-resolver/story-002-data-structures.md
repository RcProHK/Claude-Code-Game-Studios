# Story 002: Data Structures — Enums, Structs, Schema

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-07/09/21)
**Deviations**: None — HitOutcome 4-val (NORMAL_HIT=0 Family A), DamageTier 5-val, AnomalyReason 6-val; inner POD structs (CombatContext/HitResult/StatSnapshot/EnemyState/HitResolvedPayload); EnemyKilledPayload extends SerializableResource (FR-2 LootDrop chain) in src/core/enemy_killed_payload.gd
**Test Evidence**: Logic — `tests/unit/combat/test_combat_data_structures.gd`
**Code Review**: Batch A self-verified

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-006`, `TR-combat-007`, `TR-combat-014`
*(TR-combat-006: HitResolvedPayload schema 12 typed fields. TR-combat-007: combat_metric_anomaly.reason enum 6 values. TR-combat-014: HitOutcome enum exactly 4 values.)*

**ADR Governing Implementation**: ADR-0006 Contract 3 (SerializableResource envelope — `EnemyKilledPayload` extends SerializableResource for FR-2 transition_id chain); ADR-0007 (Accepted) — enum naming conventions (Family A for outcomes).
**ADR Decision Summary**: All payload structs use `extends RefCounted` (transient, non-serialized) except `EnemyKilledPayload` which extends SerializableResource for LootDrop round-trip. HitOutcome is Family A (ordinal 0 = NORMAL_HIT = safe default). DamageTier is Family A (ordinal 0 = NEGLIGIBLE = safe default).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name X extends RefCounted` for POD structs inside `combat_resolver.gd`. Inner class declarations visible to tests via preload. `class_name EnemyKilledPayload extends SerializableResource` in separate file at `src/core/enemy_killed_payload.gd`.

**Control Manifest Rules (Core layer)**:
- Required: Outcome/State enums — ordinal 0 = safe/uninitialised value (ADR-0007 Family A)
- Required: `EnemyKilledPayload` must extend `SerializableResource` with `to_dict()`/`from_dict()` for FR-2 LootDrop chain (ADR-0006 Contract 3)
- Required: `damage_tier` field in HitResult/HitResolvedPayload must NEVER be null (FR Test #4 mandatory)

---

## Acceptance Criteria

- [ ] **AC-21** — GIVEN `HitOutcome` enum declared in `CombatResolver`, WHEN `HitOutcome.values()` enumerated, THEN result equals exactly `[NORMAL_HIT=0, CRITICAL_HIT=1, KILLED=2, OVERKILL=3]` (4 values, DODGED absent per Rule 5 MVP scope). Family A: NORMAL_HIT=0 is the safe default for uninitialised HitResult.
- [ ] **AC-07** — GIVEN `HitResolvedPayload` struct (used by EnemyDirector to broadcast `hit_resolved` signal), WHEN fields inspected, THEN contains exactly: `ability_id: StringName`, `caster_id: int`, `target_id: int`, `outcome: HitOutcome`, `damage_tier: DamageTier`, `damage_dealt: int`, `damage_raw: float`, `target_hp_after: int`, `is_crit: bool`, `is_kill: bool`, `transition_id: String`, `resolved_at_tick: int` — 12 fields. `damage_tier` must never be null/missing (FR Test #4).
- [ ] **AC-09** — GIVEN `AnomalyReason` enum declared, WHEN values enumerated, THEN exactly 6 values: `GSM_SUSPENDED`, `INVALID_ABILITY_ID`, `NEGATIVE_DAMAGE`, `CLAMP_TRIGGERED`, `DEAD_TARGET_RESOLVE`, `RNG_INJECTION_MISSING`. Combat metric anomaly payloads use this enum — never free-form strings.

---

## Implementation Notes

*From GDD Rules 2, 5, 9, 10, 13 + ADR-0006 Contract 3 + ADR-0007:*

1. **In `src/core/combat_resolver.gd`** (class body, `const`/inner classes only per Rule 1):

   ```gdscript
   ## HitOutcome — Family A (ordinal 0 = NORMAL_HIT = safe default)
   enum HitOutcome { NORMAL_HIT, CRITICAL_HIT, KILLED, OVERKILL }  # 0,1,2,3
   
   ## DamageTier — Family A (ordinal 0 = NEGLIGIBLE = safe default)
   enum DamageTier { NEGLIGIBLE, LIGHT, MEDIUM, HEAVY, CRITICAL }  # 0,1,2,3,4
   
   ## AnomalyReason — Family A (ordinal 0 = safe default GSM_SUSPENDED)
   enum AnomalyReason { GSM_SUSPENDED, INVALID_ABILITY_ID, NEGATIVE_DAMAGE, CLAMP_TRIGGERED, DEAD_TARGET_RESOLVE, RNG_INJECTION_MISSING }
   
   class CombatContext extends RefCounted:
       var ability_id: StringName = &""
       var caster: Node2D
       var target: Node2D
       var caster_stats: StatSnapshot
       var target_state: EnemyState
       var rng: RandomNumberGenerator
       var transition_id: String = ""
       var gsm_state: StringName = &""
       var hit_seq: int = 0
       var ability_damage_multiplier: float = 1.0  # loaded from AbilityRegistry by caller
   
   class HitResult extends RefCounted:
       var outcome: HitOutcome = HitOutcome.NORMAL_HIT
       var damage_tier: DamageTier = DamageTier.NEGLIGIBLE
       var damage_dealt: int = 0
       var damage_raw: float = 0.0
       var target_hp_after: int = 0
       var is_kill: bool = false
       var overkill_excess: int = 0
       var is_crit: bool = false
       var ability_id: StringName = &""
       var transition_id: String = ""
   
   class StatSnapshot extends RefCounted:
       var attack_power: float = 0.0
       var crit_chance: float = 0.0
   
   class EnemyState extends RefCounted:
       var hp: int = 0
       var max_hp: int = 1
       var defense: float = 0.0
       var faction: StringName = &""
       var instance_id: int = 0
   
   class HitResolvedPayload extends RefCounted:
       var ability_id: StringName = &""
       var caster_id: int = 0
       var target_id: int = 0
       var outcome: HitOutcome = HitOutcome.NORMAL_HIT
       var damage_tier: DamageTier = DamageTier.NEGLIGIBLE  # NEVER null
       var damage_dealt: int = 0
       var damage_raw: float = 0.0
       var target_hp_after: int = 0
       var is_crit: bool = false
       var is_kill: bool = false
       var transition_id: String = ""
       var resolved_at_tick: int = 0
   ```

2. **`src/core/enemy_killed_payload.gd`** — `class_name EnemyKilledPayload extends SerializableResource` (FR-2 LootDrop chain requires SerializableResource round-trip per ADR-0006 Contract 3):
   Fields: `enemy_id: StringName`, `enemy_instance_id: int`, `killer_id: int`, `killing_ability: StringName`, `transition_id: String`, `is_overkill: bool`, `overkill_excess: int`. Implement `to_dict()` + `static from_dict()`.

3. **Performance**: All structs are pure data (no method bodies) — O(1) construction, zero heap beyond the struct.

---

## Out of Scope

- Story 003-008: resolve_hit implementation (uses these types but doesn't define them here conceptually)
- Story 009: EnemyDirector signal ownership

---

## QA Test Cases

**Story Type**: Logic

- **AC-21**: HitOutcome 4 values + NORMAL_HIT=0
  - Given: Preload CombatResolver class
  - When: `CombatResolver.HitOutcome.values()`
  - Then: Exactly [0,1,2,3]; DODGED absent; NORMAL_HIT ordinal 0

- **AC-07**: HitResolvedPayload 12 fields
  - Given: Fresh HitResolvedPayload instance
  - When: Inspect all field names via `get_property_list()`
  - Then: 12 named fields present; `damage_tier` default NEGLIGIBLE (not null/0 if zero-init)

- **AC-09**: AnomalyReason 6 values
  - Given: Preload CombatResolver class
  - When: `CombatResolver.AnomalyReason.values()`
  - Then: Exactly 6 values; canonical names match expected set

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/test_combat_data_structures.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (CI lints active)
- Unlocks: Stories 003-008 (all formula/logic stories use these types)
