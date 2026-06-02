# Story 003: Boot validation loop

> **Epic**: Exercise → Class Mapping
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/exercise-class-mapping.md`
**Requirement**: `TR-ECM-003` *(provisional — pending /architecture-review Phase 8)*

**ADR Governing Implementation**: ADR-0007: Class & Domain Enum Convention
**ADR Decision Summary**: Zero-default fabrication FORBIDDEN — an uninitialised Classification enum field silently fabricates STRIKE (ordinal 0), violating Pillar 1. Must detect and return UNKNOWN explicitly.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: validation runs over plain rows (Dictionaries) in the shared `_validate_entries()` path, so it is headless-testable via the factory without loading `.tres` or relying on `class_name` cache.

**Control Manifest Rules (this layer)**:
- Required: Classification enum fields MUST be explicitly initialised — zero-default FORBIDDEN. Sentinel default `-1` makes "unset" detectable.
- Required: return UNKNOWN explicitly on invalid — never let ordinal-0 default through.
- Guardrail: `push_error` once per invalid entry (no spam); deterministic first-wins on duplicate.

---

## Acceptance Criteria

*From GDD, scoped to this story:*

- [ ] **AC-07** entry with `ability_class` ∉ {0,1,2,3} (e.g. 99) OR `-1` (unset sentinel) → `push_error` once naming exercise_id; that entry resolves to `UNKNOWN(3)` on all subsequent lookups (no silent STRIKE via ordinal-0).
- [ ] **AC-07b** entry with `movement_pattern` ∉ {0..7} but valid `ability_class` → `push_error` once; `movement_pattern` forced to `UNKNOWN_PATTERN(7)`; entry NOT discarded — `get_class_for_exercise` still returns the valid `ability_class`.
- [ ] **AC-09** duplicate `exercise_id` → `push_error` + first entry wins (array index order).
- [ ] **AC-12** entry with `ability_class: UNKNOWN(3)` (authored intent) → returns `UNKNOWN(3)` with NO `push_error`.

---

## Implementation Notes

*Derived from ADR-0007 + GDD Rule 3 boot validation loop:*

- `_validate_entries(rows)` (shared by `_ready()` + factory) iterates all rows:
  - **ability_class**: if `ability_class == -1` (unset sentinel) OR `ability_class ∉ {0,1,2,3}` → `push_error("ExerciseRegistry: invalid/unset ability_class for [exercise_id]")` + force that entry's resolved class to `UNKNOWN(3)`.
  - **movement_pattern**: if `movement_pattern ∉ {0..7}` → `push_error` + force `movement_pattern` to `UNKNOWN_PATTERN(7)`. **Do NOT discard the entry** — `get_class_for_exercise` reads `ability_class` (Formula 1a), so a valid `ability_class` still serves.
  - **duplicate exercise_id** (after normalize): `push_error` naming the id; first-listed (lower array index) wins; later duplicates skipped from `_class_by_id`.
  - **authored UNKNOWN**: `ability_class == 3` is VALID (intentional) — must NOT `push_error` (distinguish from the `99`/`-1` invalid path).
- Validation is the only place writing the lookup dicts (with Story 004's alias-collision check). Owner self-exempt in the CI mutator-ban lint (Story 005).

---

## Out of Scope

- **Story 001**: schema, `_normalize`, happy-path build, core lookup.
- **Story 002**: MovementPattern enum + pattern lookup.
- **Story 004**: alias collision validation (alias-vs-canonical / alias-vs-alias), `is_known_exercise`, empty/FAILED.

---

## QA Test Cases

- **TC-003-01 Invalid ability_class out-of-range (AC-07 case A)**
  - Given: `_create_test_registry([{exercise_id:"bad_ordinal", movement_pattern:0, ability_class:99}])`
  - When: `_validate_entries()` runs (via factory)
  - Then: `push_error` once naming "bad_ordinal" AND `get_class_for_exercise("bad_ordinal")` returns `3`
  - Edge cases: `ability_class:4` (one above max); `ability_class:-2` (below sentinel)
- **TC-003-02 Unset ability_class sentinel `-1` (AC-07 case B)**
  - Given: `_create_test_registry([{exercise_id:"unset_entry", movement_pattern:0, ability_class:-1}])`
  - When: `_validate_entries()` runs
  - Then: `push_error` once naming "unset_entry" AND lookup returns `3`
  - Edge cases: confirms `-1` triggers detection (zero-default fabrication guard) — guard against impl that only checks `> 3` and misses `< 0`
- **TC-003-03 Invalid movement_pattern — entry NOT discarded (AC-07b)**
  - Given: `_create_test_registry([{exercise_id:"bad_pattern", movement_pattern:99, ability_class:0}])`
  - When: `_validate_entries()` runs
  - Then: `push_error` once naming "bad_pattern" AND `movement_pattern` forced to `7` AND `get_class_for_exercise("bad_pattern")` returns `0` (STRIKE) — valid ability_class served
  - Edge cases: `movement_pattern:-1`; `movement_pattern:8`
- **TC-003-04 Duplicate exercise_id — first wins (AC-09)**
  - Given: two entries id `"dup_entry"` (1st STRIKE, 2nd CONTROL)
  - When: `_validate_entries()` + `_build_lookup()`
  - Then: `push_error` (duplicate) AND `get_class_for_exercise("dup_entry")` returns `0` (first wins)
  - Edge cases: three duplicates — first wins, 2nd & 3rd skipped
- **TC-003-05 Authored UNKNOWN legal — no push_error (AC-12)**
  - Given: `_create_test_registry([{exercise_id:"intentional_unknown", movement_pattern:7, ability_class:3}])`
  - When: `_validate_entries()` runs
  - Then: NO `push_error` AND `get_class_for_exercise("intentional_unknown")` returns `3`
  - Edge cases: distinguish from AC-07 (99 invalid vs 3 valid intent)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/exercise_class_mapping/boot_validation_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`_validate_entries`/`_build_lookup` scaffold + dicts), Story 002 (MovementPattern ordinal range {0..7})
- Unlocks: Story 004 (alias collision validation extends `_validate_entries`)
