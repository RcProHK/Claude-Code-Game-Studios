# Story 001: Registry schema + core exercise lookup

> **Epic**: Exercise → Class Mapping
> **Status**: Complete (CI-green 2026-06-02 — combined gate 1250/1251, 0 fail, 1 pre-existing pending)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/exercise-class-mapping.md`
**Requirement**: `TR-ECM-001` *(provisional — not yet in tr-registry.yaml; pending /architecture-review Phase 8)*

**ADR Governing Implementation**: ADR-0007: Class & Domain Enum Convention (primary)
**Secondary**: ADR-0008 (autoload — registration in Story 005), ADR-0003 (no per-player persistence — #10 is static config, read-only)
**ADR Decision Summary**: AbilityClass is a Classification-family enum {STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3}; UNKNOWN sentinel last; zero-default fabrication FORBIDDEN; serialize enum as string name (`find_key`), never ordinal.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AbilityClass` is `AbilitySystem`'s inner enum — cannot be used as a return-type annotation cross-file (compile error). Return `int` (the `AbilitySystem.AbilityClass` ordinal), per WST precedent. A second declaration of a `STRIKE|CONTROL|MOBILITY` enum anywhere is a CI error — reference the canonical one, never redeclare.

**Control Manifest Rules (this layer)**:
- Required: Classification enum fields MUST be explicitly initialised — zero-default FORBIDDEN (ordinal 0 = STRIKE is a real value, not a sentinel). Return UNKNOWN explicitly on miss.
- Required: `AbilityClass` is the ONE canonical class-archetype enum across all systems — never redeclare STRIKE/CONTROL/MOBILITY.
- Forbidden: serialize enum values as integer ordinals — use `EnumType.find_key(value)` → String.
- Guardrail: pure lookup, no per-player persistence (ADR-0003), no GSM subscription.

---

## Acceptance Criteria

*From GDD `design/gdd/exercise-class-mapping.md`, scoped to this story:*

- [ ] **AC-01** registry exact hit: `_create_test_registry([{exercise_id:"test_push_a", movement_pattern:0, ability_class:0}])` → `get_class_for_exercise("test_push_a")` returns `0` (STRIKE).
- [ ] **AC-03 (id-side)** unknown exercise → `UNKNOWN(3)` (never fabricated).
- [ ] **AC-04** precedence: entry `{movement_pattern:PUSH(0), ability_class:CONTROL(1)}` → `get_class_for_exercise` returns `CONTROL(1)` NOT `STRIKE(0)` (reads `ability_class`, not `movement_pattern`; two entry points independent, no fallback).
- [ ] **AC-08** determinism: same id, two lookups → identical.
- [ ] **AC-10** normalize: `"bench press"` / `"Bench_Press"` → same class as canonical `"bench_press"`.

---

## Implementation Notes

*Derived from ADR-0007 + GDD Rule 1/2/3 + Pass-2 type-contract resolution:*

- **`ExerciseEntry extends Resource`** (`class_name ExerciseEntry`): `@export` `exercise_id: String`, `movement_pattern: int = -1`, `ability_class: int = -1`, `muscle_group: String`, `aliases: Array[String]`. **Sentinel default `-1` (NOT 0)** — unset field must be detectable (boot validation in Story 003); `0` would silently fabricate STRIKE (ADR-0007 zero-default FORBIDDEN).
- **`ExerciseRegistry extends Resource`** (`class_name ExerciseRegistry`): `@export var entries: Array[ExerciseEntry]`.
- **`_normalize(raw) -> String`** single helper: first line `var s := String(raw)` (force `StringName→String` cast — GDScript 4.x Dictionary `&"x" != "x"`, must cast or alias lookups silently miss), then `s.to_lower().strip_edges()` + collapse consecutive spaces to single `_`. Both API entry points call `_normalize()` first.
- **Runtime representation** (NOT the `.tres` schema): boot flattens `Array[ExerciseEntry]` → two `Dictionary`: `_class_by_id` (normalized `String` → `int` ability_class) + `_canonical_by_alias` (normalized alias `String` → canonical `String`). Runtime lookups read only these dicts.
- **`_validate_entries(rows)` + `_build_lookup(rows)`** private path shared by `_ready()` and the test factory. **`_create_test_registry(entries: Array[Dictionary]) -> void`** takes `Array[Dictionary]` directly — does NOT instantiate `ExerciseEntry.new()` (zero `class_name` cache dependency — headless GUT safe).
- **`get_class_for_exercise(exercise_id: StringName) -> int`** (Formula 1a): `_normalize` → exact `_class_by_id` match → return ability_class; else `UNKNOWN(3)`. No pattern_map fallback (that is Story 002's separate entry point).
- Boot validation loop bodies (sentinel/ordinal/dup/alias) are Story 003/004 — this story scaffolds `_validate_entries()` and the happy-path build.

---

## Out of Scope

- **Story 002**: `get_class_for_movement_pattern` + MovementPattern enum + pattern_map.
- **Story 003**: full boot validation (invalid ordinal/sentinel/dup/authored-UNKNOWN push_error paths).
- **Story 004**: alias resolution path, collision policy, `is_known_exercise`, empty/FAILED edge cases.
- **Story 005**: autoload pos 5 registration + CI mutator-ban lint.

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these — do not invent new cases.*

- **TC-001-01 Registry exact hit (AC-01)**
  - Given: `_create_test_registry([{exercise_id:"test_push_a", movement_pattern:0, ability_class:0}])`
  - When: `get_class_for_exercise("test_push_a")`
  - Then: returns `0` (STRIKE)
  - Edge cases: n/a (baseline)
- **TC-001-02 Registry miss → UNKNOWN (AC-03 id-side)**
  - Given: `_create_test_registry([])` (empty)
  - When: `get_class_for_exercise("nonexistent_exercise")`
  - Then: returns `3` (UNKNOWN)
  - Edge cases: also registry with entries but query a missing id
- **TC-001-03 Precedence — ability_class overrides movement_pattern (AC-04)**
  - Given: `_create_test_registry([{exercise_id:"test_conflict", movement_pattern:0 /*PUSH*/, ability_class:1 /*CONTROL*/}])`
  - When: `get_class_for_exercise("test_conflict")`
  - Then: returns `1` (CONTROL), NOT `0`
  - Edge cases: verify `get_class_for_movement_pattern(0)` separately returns `0` — confirms entry points independent
- **TC-001-04 Determinism (AC-08)**
  - Given: registry with `test_push_a`
  - When: `get_class_for_exercise("test_push_a")` twice
  - Then: both return identical `0`
- **TC-001-05 Normalize — space→underscore + lowercase (AC-10)**
  - Given: registry with canonical `"bench_press"`
  - When: `get_class_for_exercise("bench press")` AND `get_class_for_exercise("Bench_Press")`
  - Then: both return `0`; equal to canonical lookup
  - Edge cases: `"BENCH  PRESS"` (double space) → `"bench_press"` → STRIKE
- **TC-001-06 StringName cast (ADVISORY — `_normalize` first line)**
  - Given: registry with `"bench_press"`
  - When: `get_class_for_exercise(&"bench_press")` (StringName)
  - Then: same result as `String` `"bench_press"`
  - Edge cases: `&""` empty StringName → UNKNOWN + push_warning (AC-11, Story 004)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/exercise_class_mapping/registry_lookup_test.gd` — must exist and pass (combined GUT gate green)
**Status**: [x] Created + passing — 12 test functions (TC-001-01..06 + AC-07/07b/12 scaffold coverage); combined gate CI-green 2026-06-02 (1250/1251, 0 fail; 1 pending = pre-existing AC-37 WST, not this story)

---

## Dependencies

- Depends on: None (foundational story for this epic)
- Unlocks: Story 002, Story 003, Story 004 (all build on schema + `_normalize` + `_build_lookup`)
