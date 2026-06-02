# Story 004: Alias resolution + collision + is_known + edge/FAILED

> **Epic**: Exercise → Class Mapping
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/exercise-class-mapping.md`
**Requirement**: `TR-ECM-004` *(provisional — pending /architecture-review Phase 8)*

**ADR Governing Implementation**: ADR-0007: Class & Domain Enum Convention
**ADR Decision Summary**: no-fabrication — miss/empty/failure all resolve to UNKNOWN explicitly, never a fabricated class. Pure deterministic resolution.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_load_registry()` MUST be an injectable/overridable seam (returns the registry source; test override returns `null`) so the FAILED-state AC-06 is headless-verifiable. Do NOT call `load()` directly inline. `StringName→String` cast in `_normalize` is critical for alias dict hits (`&"x" != "x"` as GDScript dict keys).

**Control Manifest Rules (this layer)**:
- Required: return UNKNOWN explicitly on miss/empty/failure — never zero-default.
- Required: `is_known_exercise` and `get_class_for_exercise` MUST share the same `_normalize` + alias resolution path (consistency).
- Guardrail: FAILED state `push_error` once (no spam on repeated lookups); empty input `push_warning` (not error).

---

## Acceptance Criteria

*From GDD, scoped to this story:*

- [ ] **AC-05** alias `"Bench Press"→bench_press` → `lookup("Bench Press")` returns STRIKE.
- [ ] **AC-05b** alias stored `"Bench Press"`, query `"bench press"` (lowercase) → same class as canonical (normalize runs before alias resolution).
- [ ] **AC-06** `_load_registry()` seam returns null → all lookups `UNKNOWN(3)` + `push_error` once, no crash (FAILED degrade).
- [ ] **AC-11** empty `""` / `&""` → `UNKNOWN(3)` + `push_warning` once, no crash.
- [ ] **AC-14a/b/c/d** `is_known_exercise`: known→true / unknown→false / unnormalized alias→true / empty→false (no crash).
- [ ] **AC-15** alias collision (alias-vs-canonical AND alias-vs-alias) → `push_error` + first-listed wins + collision alias skipped; deterministic.

---

## Implementation Notes

*Derived from ADR-0007 + GDD Rule 5/7 + Edge Cases + Pass-2 alias-collision policy:*

- **Alias path** in `get_class_for_exercise`: after `_normalize`, if not in `_class_by_id`, check `_canonical_by_alias` → canonical → `_class_by_id`. Normalize runs BEFORE alias dict lookup (AC-05b).
- **Alias collision** (extends Story 003's `_validate_entries`): when building `_canonical_by_alias`, if a normalized alias collides with an existing canonical id OR another alias → `push_error` naming the key + first-listed wins (canonical priority; aliases by entry array index then alias array index) + skip the colliding alias entirely. Preserves determinism (AC-08).
- **`is_known_exercise(exercise_id: StringName) -> bool`**: shares `_normalize` + the same canonical/alias resolution as `get_class_for_exercise` (divergence = bug). Empty → false. No `push_warning` (that belongs to `get_class_for_exercise` per AC-11).
- **Empty input**: `_normalize` → empty-check: `""` / `&""` → `UNKNOWN(3)` + `push_warning` once.
- **FAILED state**: `_load_registry()` injectable seam; if it returns null (missing/corrupt) → enter FAILED, all lookups `UNKNOWN(3)`, `push_error` once total (state persists, no per-call spam).

---

## Out of Scope

- **Story 001/002/003**: core lookups, pattern enum, ability_class/movement_pattern/dup validation.
- **Story 005**: autoload registration + CI mutator-ban lint.

---

## QA Test Cases

- **TC-004-01 Alias lookup — title case (AC-05)**: registry `{exercise_id:"bench_press", ability_class:0, aliases:["Bench Press"]}` → `get_class_for_exercise("Bench Press")` → `0`.
- **TC-004-02 Alias normalize-before-resolve (AC-05b)**: same registry → `get_class_for_exercise("bench press")` (lowercase) → `0`. Edge: `"BENCH PRESS"` all-caps → resolves.
- **TC-004-03 FAILED via injectable seam (AC-06)**: `_load_registry()` overridden → null → `get_class_for_exercise("any")` → `3` + `push_error` once + no crash. Edge: subsequent calls still `3`, error count stays 1.
- **TC-004-04 Empty String → UNKNOWN + push_warning (AC-11)**: `get_class_for_exercise("")` → `3` + `push_warning` once + no crash.
- **TC-004-05 Empty StringName → UNKNOWN + push_warning (AC-11)**: `get_class_for_exercise(&"")` → `3` + `push_warning` once. Edge: confirm `_normalize` converts `&""`→`""` before empty-check.
- **TC-004-06 is_known known (AC-14a)**: `is_known_exercise("bench_press")` → true.
- **TC-004-07 is_known unknown (AC-14b)**: `is_known_exercise("nonexistent")` → false.
- **TC-004-08 is_known unnormalized alias (AC-14c)**: `is_known_exercise("Bench Press")` → true (shares normalize+alias path).
- **TC-004-09 is_known empty (AC-14d)**: `is_known_exercise("")` AND `is_known_exercise(&"")` → false, no crash, no push_warning.
- **TC-004-10 Alias collision — alias vs canonical (AC-15 A)**: entry A `{bench_press, STRIKE}` + entry B `{lat_pulldown, CONTROL, aliases:["bench_press"]}` → `push_error` naming "bench_press" + `lookup("bench_press")`→`0` (A wins) + `lookup("lat_pulldown")`→`1`. Collision alias skipped.
- **TC-004-11 Alias collision — alias vs alias (AC-15 B)**: entry A `{exercise_a, STRIKE, aliases:["shared_alias"]}` + entry B `{exercise_b, CONTROL, aliases:["shared_alias"]}` → `push_error` "shared_alias" + `lookup("shared_alias")`→`0` (lower index wins) + `lookup("exercise_b")` still works. Edge: three same alias → first wins, rest skipped.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/exercise_class_mapping/alias_and_edge_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`_normalize`, dicts, core lookup), Story 003 (`_validate_entries` — alias collision extends it)
- Unlocks: Story 005 (full API surface complete → autoload registration + CI lint)
