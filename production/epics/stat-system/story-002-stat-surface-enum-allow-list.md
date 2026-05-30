# Story 002: Stat Surface + StatSource Enum + Allow-List

> **Epic**: Stat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-01 ✓ AC-04 ✓ AC-05 ✓)
**Deviations**: ADVISORY — DEFAULT_BASE_VALUE=10.0 / DERIVED_PLACEHOLDER=0.0 hardcoded (Story 011 replaces); TR-stat-001 registry stale text (architecture-review deferred)
**Test Evidence**: Logic — 3 unit test files at tests/unit/stat_system/ (12 test functions total)
**Code Review**: Complete — CHANGES REQUIRED (2 AC deviations) → fixes applied → APPROVED

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-001`, `TR-stat-003`, `TR-stat-004`
*(TR-stat-001: 7-stat surface LOCKED. TR-stat-003: StatSource enum 5 values. TR-stat-004: Source/stat allow-list — PR_BREAKTHROUGH base-only)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 3 (typed enum, string-name serialization), Contract 12 (chokepoint enforcement); ADR-0007 Class & Domain Enum Convention — Family B (Classification enum: declaration order load-bearing, UNKNOWN last, zero-default FORBIDDEN)
**ADR Decision Summary**: Enums are typed and serialized as string names. Classification enums must have explicit sentinel last; CallerID must be explicitly returned, never zero-defaulted. StatSource.INITIAL_STATE is a sentinel-only value — not a valid mutation source.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript 4.6 enum values are plain ints; `StatSource.values()` returns an Array of ints. `find_key(value)` for enum→String is a 4.4+ API. Typed `@export var x: StatSource` defaults to ordinal 0 — caller must explicitly set source.

**Control Manifest Rules (Core layer)**:
- Required: Classification enum fields must be explicitly initialised — zero-default fabrication FORBIDDEN (ADR-0007 Family B)
- Required: `AbilityClass` is the canonical class-archetype enum — `StatSource` is a separate mutation-source enum (not AbilityClass); do not conflate
- Forbidden: No `LOOT_RANDOM`, `LEVEL_UP_BONUS`, `STREAK_BONUS` or any RNG-based source may be added to `StatSource` — FR-1 binding

---

## Acceptance Criteria

- [ ] **AC-01** — GIVEN Stat System in Ready substate, WHEN `get_stat(StatId.STR)` / `get_stat(StatId.DEX)` / `get_stat(StatId.VIT)` / `get_stat(StatId.MAX_HP)` / `get_stat(StatId.ATTACK_POWER)` / `get_stat(StatId.MOVE_SPEED)` / `get_stat(StatId.CRIT_CHANCE)` are called, THEN all 7 return a float value; AND WHEN `get_stat("luk")` (unknown stat_id) is called, THEN returns `NAN` OR triggers push_error reject (either acceptable — test asserts no crash + `stat_mutation_rejected` telemetry fires with reason `"invalid_stat_id"`).
- [ ] **AC-04** — GIVEN Stat System runtime, WHEN `StatSource.values()` is inspected, THEN returns an array of exactly 5 elements containing `PR_BREAKTHROUGH`, `VOLUME_TICK`, `EQUIPMENT`, `DEBUG_OVERRIDE`, `INITIAL_STATE`; AND WHEN `apply_stat_delta(StatId.STR, StatSource.INITIAL_STATE, 1.0)` is called, THEN returns `false` + push_error fires + `stat_mutation_rejected` fires with reason `"invalid_source"`.
- [ ] **AC-05** — GIVEN Stat System Ready, STR=10, WHEN `apply_stat_delta(StatId.STR, StatSource.PR_BREAKTHROUGH, 1.0)` (allowed), THEN returns `true` + STR rises to 11.0; AND WHEN `apply_stat_delta(StatId.MAX_HP, StatSource.PR_BREAKTHROUGH, 50.0)` (disallowed), THEN returns `false` + `stat_mutation_rejected(MAX_HP, PR_BREAKTHROUGH, 50.0, "source_stat_mismatch")` fires + MAX_HP unchanged.

---

## Implementation Notes

*From GDD Rules 1, 2, 3, 4:*

1. **`class StatId`** — StringName constants: `STR`, `DEX`, `VIT`, `MAX_HP`, `ATTACK_POWER`, `MOVE_SPEED`, `CRIT_CHANCE`. `_base` dictionary only stores `STR/DEX/VIT`; derived are computed on read. Unknown stat_id → push_error + `stat_mutation_rejected(stat_id, source, delta, "invalid_stat_id")` + return `NAN` from `get_stat`.
2. **`enum StatSource`** — 5 values exactly: `PR_BREAKTHROUGH=0`, `VOLUME_TICK=1`, `EQUIPMENT=2`, `DEBUG_OVERRIDE=3`, `INITIAL_STATE=4`. FR-1 binding: this set is LOCKED — do not add `LOOT_RANDOM` or any RNG-based source.
3. **Allow-list** (Rule 4) — implemented as a Dictionary constant `_SOURCE_ALLOWED_STATS`:
   - `PR_BREAKTHROUGH` → `[STR, DEX, VIT]` (base only)
   - `VOLUME_TICK` → `[STR, DEX, VIT]` (base only)
   - `EQUIPMENT` → all 7
   - `DEBUG_OVERRIDE` → all 7
   - `INITIAL_STATE` → `[]` (empty — reject all)
4. **`apply_stat_delta` validation sequence** (Rule 13 step 1):
   - Check `_SOURCE_ALLOWED_STATS.has(source)` — invalid enum → push_error + `stat_mutation_rejected(..., "invalid_source")`
   - Check `stat_id in _SOURCE_ALLOWED_STATS[source]` — mismatch → push_error + `stat_mutation_rejected(..., "source_stat_mismatch")`
   - These checks fire before any persistence or mutation
5. **Performance**: `get_stat()` is a dictionary read (O(1), no allocation). `apply_stat_delta` validation is two dictionary lookups. Both are negligible vs the 16.6ms frame budget. Formal profiling of the derived-stat computation path is deferred to Story 010.

---

## Out of Scope

- Story 003: Equipment modifier `apply_equipment_modifier` / `remove_equipment_modifier` implementation
- Story 004: Boot reconciliation (`_ready()` sync read)
- Story 006: Persistence flush + atomic write ordering
- Derived stat formulas (Stories 010-011)

---

## QA Test Cases

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_stat_surface_locked.gd`, `test_stat_source_enum.gd`, `test_source_stat_allow_list.gd`

- **AC-01**: Stat surface locked
  - Given: Stat System Ready (STR=DEX=VIT=10 defaults)
  - When: Call `get_stat` for each of the 7 known stat IDs, then call `get_stat("luk")`
  - Then: All 7 return float; `get_stat("luk")` returns NAN OR triggers push_error (no crash); `stat_mutation_rejected` fires with `"invalid_stat_id"`
  - Edge cases: `get_stat("")` (empty string) — same reject path; `get_stat(StatId.STR)` (using StatId constant) vs `get_stat("str")` (magic string) — only the StatId constant path is guaranteed

- **AC-04**: StatSource enum completeness + INITIAL_STATE sentinel
  - Given: Stat System runtime
  - When: (a) Inspect `StatSource.values()`; (b) Call `apply_stat_delta(StatId.STR, StatSource.INITIAL_STATE, 1.0)`
  - Then: (a) Array has exactly 5 elements, contains all 5 named values; (b) Returns false, push_error fires, `stat_mutation_rejected` fires with `"invalid_source"`, STR unchanged
  - Edge cases: Any future addition of a 6th StatSource value → test fails immediately (enum closed-set guard)

- **AC-05**: Source/stat allow-list
  - Given: STR=10, Ready substate
  - When: (a) `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` — allowed; (b) `apply_stat_delta(MAX_HP, PR_BREAKTHROUGH, 50.0)` — disallowed
  - Then: (a) Returns true, STR=11.0; (b) Returns false, `stat_mutation_rejected(MAX_HP, PR_BREAKTHROUGH, 50.0, "source_stat_mismatch")` fires, MAX_HP unchanged
  - Edge cases: `apply_stat_delta(STR, EQUIPMENT, 5.0)` → reject (EQUIPMENT goes through `apply_equipment_modifier` Rule 5, not `apply_stat_delta` for base stats — verify Rule 4 allows EQUIPMENT on all-7 but test the expected path)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Unit tests in `tests/unit/stat_system/` — `test_stat_surface_locked.gd`, `test_stat_source_enum.gd`, `test_source_stat_allow_list.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (CI lints must exist before runtime code, so violations are caught on first commit)
- Unlocks: Story 003 (equipment modifier uses same `apply_stat_delta` validation), Story 004 (boot uses same stat surface), Story 005 (observer delivers these stat IDs)
