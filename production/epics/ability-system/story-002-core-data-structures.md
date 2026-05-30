# Story 002: Core Data Structures — AbilityId, Enums, Signals

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 6/6 passing (AC-01/03/05/06/19/20)
**Deviations**: AbilityClass = 4 values {STRIKE,CONTROL,MOBILITY,UNKNOWN} per ADR-0007 Family B (GDD said 3; ADR-0007 Accepted takes precedence) — AC-03 test verifies 4 + UNKNOWN last
**Test Evidence**: Logic — test_ability_id_surface/enums_locked/unlock_source_enum/cast_result_enum/single_character_scope/telemetry_signals (6 files)
**Code Review**: Batch A self-verified

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-001`, `TR-ability-002`, `TR-ability-004`, `TR-ability-005`, `TR-ability-016`
*(TR-ability-001: Ability ID surface LOCKED. TR-ability-002: AbilityClass + AbilityTier enums LOCKED. TR-ability-004: UnlockSource 3 values. TR-ability-005: CastResult 6 outcomes. TR-ability-016: 7 signals.)*

**ADR Governing Implementation**: ADR-0006 Contract 3 (SerializableResource envelope — `UnlockRecord` will extend it); ADR-0007 (Accepted 2026-05-29) — Family B Classification enum for `AbilityClass`: STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3 (sentinel LAST, zero-default FORBIDDEN).
**ADR Decision Summary**: `AbilityClass` is Family B — declaration order load-bearing (Formula 3 emit sort), sentinel UNKNOWN last, no zero-default fabrication. GDD AC-03 specified 3 values; ADR-0007 locks 4 (adds UNKNOWN sentinel) — ADR-0007 takes precedence.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript enum reflection via `.values()` returns Array of ints; `.keys()` returns Array of String names. `class AbilityId` inner class with StringName const accessible from class and instance. `signal` with typed params valid in Godot 4.6.

**Control Manifest Rules (Core layer)**:
- Required: Classification enum fields MUST be explicitly initialised — zero-default fabrication FORBIDDEN (ADR-0007 Family B)
- Required: `AbilityClass` is the canonical class-archetype enum; declaration order locked STRIKE/CONTROL/MOBILITY/UNKNOWN (ordinals 0/1/2/3)
- Required: Serialize enum as String name (find_key/get) — never int ordinal

---

## Acceptance Criteria

- [ ] **AC-01** — GIVEN `class AbilityId` declared in `src/autoload/ability_system.gd`, WHEN static analysis enumerates all StringName constants under `AbilityId`, THEN count equals exactly 9: `{STRIKE_TIER_1_JAB, STRIKE_TIER_2_HOOK, STRIKE_TIER_3_OVERHAND, CONTROL_TIER_1_PARRY, CONTROL_TIER_2_HOOK_PULL, CONTROL_TIER_3_GRAPPLE, MOBILITY_TIER_1_DASH, MOBILITY_TIER_2_LEAP, MOBILITY_TIER_3_GROUND_POUND}`.
- [ ] **AC-03** — GIVEN `AbilityClass` and `AbilityTier` enums declared per ADR-0007 (Family B), WHEN `AbilityClass.values()` and `AbilityTier.values()` enumerated, THEN `AbilityClass` returns exactly `[STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3]` (4 values per ADR-0007 — UNKNOWN sentinel last; GDD specified 3 values but ADR-0007 Accepted 2026-05-29 takes precedence) AND `AbilityTier` returns exactly `[TIER_1, TIER_2, TIER_3]` (3 values).
- [ ] **AC-05** — GIVEN `UnlockSource` enum declared, WHEN `UnlockSource.values()` enumerated AND `unlock_ability(AbilityId.STRIKE_TIER_1_JAB, UnlockSource.INITIAL_STATE)` called, THEN `UnlockSource.values()` equals exactly `[PR_BREAKTHROUGH, STAT_THRESHOLD, INITIAL_STATE]` AND the sentinel call returns `false` + emits `ability_mutation_rejected(STRIKE_TIER_1_JAB, INITIAL_STATE, "sentinel_misuse")`.
- [ ] **AC-06** — GIVEN `CastResult` enum declared, WHEN `CastResult.values()` enumerated, THEN result equals exactly `[SUCCESS, NOT_UNLOCKED, ON_COOLDOWN, STAT_INSUFFICIENT, INVALID_TARGET, GSM_REJECT]` (6 entries) AND `cast_ability` return type annotation is `CastResult`.
- [ ] **AC-19** — GIVEN AbilitySystem public API, WHEN `unlock_ability`, `cast_ability`, `get_unlocked_abilities`, `get_ability_state` signatures inspected, THEN none contain parameter named `character_id` or `char_id` (single-character MVP scope — Rule 15).
- [ ] **AC-20** — GIVEN AbilitySystem signal declarations, WHEN signal list enumerated, THEN exactly 7 signals present: `ability_unlocked(ability_id: StringName, source: int)`, `ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)`, `ability_cooldown_started(ability_id: StringName, duration: float)`, `ability_cooldown_ended(ability_id: StringName)`, `ability_mutation_rejected(ability_id: StringName, source: int, reason: String)`, `ability_cast_rejected(ability_id: StringName, reason: String)`, `ability_unlock_save_failed(ability_id: StringName)`.

---

## Implementation Notes

*From GDD Rules 1, 2, 4, 5, 15, 16 + ADR-0007 Family B:*

1. **`class AbilityId`** — 9 StringName const: `STRIKE_TIER_1_JAB = &"strike_tier_1_jab"` etc. (lowercase StringName literals per naming convention)
2. **`enum AbilityClass { STRIKE, CONTROL, MOBILITY, UNKNOWN }`** — Family B per ADR-0007. Ordinals 0/1/2/3 load-bearing for Formula 3 emit sort. `UNKNOWN` is anti-fabrication sentinel; a producer returning `UNKNOWN` MUST do so explicitly, never via zero-default.
3. **`enum AbilityTier { TIER_1, TIER_2, TIER_3 }`** — ordinals 0/1/2 load-bearing for Formula 3 sort.
4. **`enum UnlockSource { PR_BREAKTHROUGH, STAT_THRESHOLD, INITIAL_STATE }`** — FR-1 binding: set LOCKED. `INITIAL_STATE` is the ADR-006 Contract 6 sentinel.
5. **`enum CastResult { SUCCESS, NOT_UNLOCKED, ON_COOLDOWN, STAT_INSUFFICIENT, INVALID_TARGET, GSM_REJECT }`**
6. **Public API signatures** (stub bodies — full implementation in stories 004-008):
   - `func unlock_ability(ability_id: StringName, source: UnlockSource) -> bool`
   - `func cast_ability(ability_id: StringName, caster: Node2D, target: Node2D) -> CastResult`
   - `func get_unlocked_abilities() -> Dictionary` (returns read-only view)
   - `func get_ability_state(ability_id: StringName) -> Dictionary`
7. **7 signals** with typed signatures per AC-20. `source` typed as `int` (not enum) for signal compatibility.
8. **`boot_completed()` signal** also required (Rule 16, AC-14c context) — declare alongside the 7.
9. **Note for CI lints**: `AbilityClass` declaration must appear BEFORE `AbilityId` in the file so the enum is resolvable at const parse time if cross-referenced.
10. **Performance**: Declarations only. No performance concern.

---

## Out of Scope

- Story 003: Source→class allow-list runtime validation
- Story 004-008: All runtime implementation (unlock/cast/boot/GSM logic)
- Story 001: CI lints that guard against misuse of these data structures

---

## QA Test Cases

**Story Type**: Logic

- **AC-01**: AbilityId 9 constants
  - Given: Fresh instance of stat_system preloaded (un-parented)
  - When: Enumerate all StringName const under AbilityId via reflection
  - Then: Exactly 9 constants with canonical names
  - Edge cases: No extra ID (e.g., `STRIKE_TIER_4`) — count must be exactly 9

- **AC-03**: AbilityClass 4-value Family B enum
  - Given: preload script
  - When: `AbilityClass.values().size()` AND `AbilityClass.keys()`
  - Then: 4 values; UNKNOWN is index 3 (last); STRIKE=0 (not zero-default-safe)
  - Edge cases: Confirm ordinals 0/1/2/3 match STRIKE/CONTROL/MOBILITY/UNKNOWN order

- **AC-05**: UnlockSource sentinel reject
  - Given: Fresh instance (no PL/GSM injection needed for this enum-level check)
  - When: Call `unlock_ability(AbilityId.STRIKE_TIER_1_JAB, UnlockSource.INITIAL_STATE)`
  - Then: Returns false; `ability_mutation_rejected` fires with reason "sentinel_misuse"

- **AC-06**: CastResult 6 outcomes
  - Given: Enum reflection
  - When: `CastResult.values()`
  - Then: Exactly 6 entries matching canonical set

- **AC-19**: Single-character scope
  - Given: Class method signatures
  - When: Check parameter names of all 4 public API methods
  - Then: No `character_id` parameter exists

- **AC-20**: 7 signals declared
  - Given: Signal list reflection
  - When: Enumerate all signals
  - Then: Exactly 7 signals with canonical names; no extra signals

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ability_system/test_ability_id_surface.gd`, `test_enums_locked.gd`, `test_unlock_source_enum.gd`, `test_cast_result_enum.gd`, `test_single_character_scope.gd`, `test_telemetry_signals.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (CI lints must exist so any future enum violation is caught immediately)
- Unlocks: Story 003 (allow-list), Story 004 (unlock path), Story 005 (unlock path B), Story 006 (cast + cooldown)
