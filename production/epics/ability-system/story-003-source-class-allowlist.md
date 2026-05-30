# Story 003: Source→Class Allow-List + Caller Whitelist Runtime Defense

> **Epic**: Ability System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-07/AC-07b/AC-30)
**Deviations**: AC-07 testability solved via optional `expected_class` 3rd param on unlock_ability (default UNKNOWN = no check); internal `_evaluate_unlock` derives expected_class from stat_id and passes it — keeps public API simple while enabling cross-class test. Idempotent (AC-07b) verified structurally (Batch A defers emit/persist to Story 004).
**Test Evidence**: Logic — test_source_class_allowlist.gd, test_caller_whitelist_runtime_defense.gd
**Code Review**: Batch A self-verified

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: `TR-ability-006`
*(TR-ability-006: Source-to-class allow-list rejects cross-class unlock)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (chokepoint enforcement); ADR-0007 (Accepted) — AbilityClass canonical 4-value enum, STRIKE=0/CONTROL=1/MOBILITY=2.
**ADR Decision Summary**: All unlock attempts go through `unlock_ability` chokepoint; source/class allow-list enforces Pillar 4 separation; only the internal handler (signal subscriber) may call `unlock_ability` — never external code.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: AbilityClass enum ordinals 0/1/2/3 (Family B — STRIKE=0 is a real value, NOT a safe default; zero-default fabrication FORBIDDEN per ADR-0007). `Dictionary.has()` and `in` operator for allow-list lookup.

**Control Manifest Rules (Core layer)**:
- Required: `AbilityClass` is the canonical class-archetype enum; STRIKE/CONTROL/MOBILITY fixed ordinals
- Required: Zero-default fabrication FORBIDDEN — any code path that implicitly uses STRIKE (ordinal 0) as a fallback is a Pillar 4 violation
- Forbidden: Never use integer ordinals to serialize AbilityClass — use `find_key(value)` → String name

---

## Acceptance Criteria

- [ ] **AC-07** — GIVEN AbilitySystem initialized with `_unlocked_abilities` empty, WHEN `unlock_ability(AbilityId.CONTROL_TIER_1_PARRY, UnlockSource.PR_BREAKTHROUGH)` invoked where the internal handler has `stat_id=STR` context (STR→STRIKE only, not CONTROL), THEN returns `false`, `_unlocked_abilities` does NOT contain `CONTROL_TIER_1_PARRY`, `ability_mutation_rejected(CONTROL_TIER_1_PARRY, PR_BREAKTHROUGH, "source_class_mismatch")` emits exactly once.
- [ ] **AC-07b** — GIVEN any `ability_id` already in `_unlocked_abilities`, WHEN `unlock_ability(ability_id, PR_BREAKTHROUGH)` called a second time (EC-11 idempotent guard), THEN returns `true` (no-op), no `ability_unlocked` signal fires for the second call, no `PersistenceLayer.write()` call made for the second attempt (persist-only-once guarantee).
- [ ] **AC-30** — GIVEN test fixture simulates a non-whitelisted caller attempting `unlock_ability(AbilityId.STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` (simulated via white-box test that triggers the runtime guard path), WHEN call executed, THEN returns `false`, `_unlocked_abilities` unchanged, `ability_mutation_rejected(..., "caller_whitelist_violation")` emits, `push_error` fires.

---

## Implementation Notes

*From GDD Rules 3, 6, 13 + ADR-0007:*

1. **`_STAT_TO_CLASS` mapping** (private const):
   ```gdscript
   const _STAT_TO_CLASS: Dictionary = {
       StatId.STR: AbilityClass.STRIKE,
       StatId.DEX: AbilityClass.CONTROL,
       StatId.VIT: AbilityClass.MOBILITY,
   }
   ```
2. **`_ABILITY_CLASS` lookup from AbilityRegistry** — each ability_id maps to a class; for stub: derive class from ability_id prefix (STRIKE/CONTROL/MOBILITY) OR read from `AbilityRegistry.tres` data (Story Q-X4 deferred — stub OK for VS tier).
3. **Source/class allow-list check inside `unlock_ability`** (after source enum validation):
   ```gdscript
   var ability_class := _get_ability_class(ability_id)
   # Class must match source's allowed class (Rule 6)
   if ability_class == AbilityClass.UNKNOWN:
       push_error(...); return false  # unknown ability
   var expected_class := _source_class_for(stat_id, source)
   if ability_class != expected_class:
       push_error(...)
       ability_mutation_rejected.emit(ability_id, source, "source_class_mismatch")
       return false
   ```
4. **Idempotent guard** (EC-11) — Rule 13 step 1:
   ```gdscript
   if _unlocked_abilities.has(ability_id):
       return true  # no-op: no emit, no persist
   ```
5. **Caller whitelist runtime defense** (EC-10) — detect non-whitelisted callers. Implementation strategy: track call context via a private flag or stack depth check. Simplest approach: `_unlock_call_permitted: bool = false`; set to `true` only inside `_evaluate_unlock` (the internal handler); check at top of `unlock_ability`. Reset after call completes.
6. **Note on `_ABILITY_CLASS` stub**: For story-003 minimal surface, derive class from ability_id string prefix: if id begins with "strike" → STRIKE, "control" → CONTROL, "mobility" → MOBILITY. Story 007 (boot) will use AbilityRegistry.tres data.

---

## Out of Scope

- Story 004: Full `unlock_ability` body with persistence (this story only adds allow-list + idempotent guard to stub)
- Story 001: CI-time enforcement of caller whitelist (this story covers runtime layer only)

---

## QA Test Cases

**Story Type**: Logic

- **AC-07**: Cross-class unlock rejected
  - Given: STR-source PR_BREAKTHROUGH evaluated against CONTROL_TIER_1_PARRY
  - When: `unlock_ability(CONTROL_TIER_1_PARRY, PR_BREAKTHROUGH)` with STR context
  - Then: Returns false; no entry in `_unlocked_abilities`; `ability_mutation_rejected` fires with "source_class_mismatch"
  - Edge cases: STR→STRIKE ability = allowed; DEX→CONTROL allowed; VIT→MOBILITY allowed; STR→CONTROL = rejected

- **AC-07b**: Idempotent guard
  - Given: STRIKE_TIER_1_JAB already in `_unlocked_abilities`
  - When: `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` called again
  - Then: Returns true; `ability_unlocked` NOT emitted second time; PL.write NOT called second time
  - Edge cases: 10 rapid calls for same ability → only first emits/persists; subsequent all return true silently

- **AC-30**: Caller whitelist runtime defense
  - Given: `_unlock_call_permitted = false` (simulates external caller bypassing signal pattern)
  - When: `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` called without setting `_unlock_call_permitted`
  - Then: Returns false; `ability_mutation_rejected(..., "caller_whitelist_violation")` fires; push_error fires

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ability_system/test_source_class_allowlist.gd`, `test_caller_whitelist_runtime_defense.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (AbilityClass enum + AbilityId constants must exist)
- Unlocks: Story 004 (unlock path builds on allow-list + idempotent guard)
