# Story 002: Movement-pattern lookup + MovementPattern enum

> **Epic**: Exercise → Class Mapping
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/exercise-class-mapping.md`
**Requirement**: `TR-ECM-002` *(provisional — pending /architecture-review Phase 8)*

**ADR Governing Implementation**: ADR-0007: Class & Domain Enum Convention
**ADR Decision Summary**: Classification enums — declaration order load-bearing, sentinel last, zero-default fabrication FORBIDDEN. `MovementPattern` is a NEW Classification-family enum owned by #10 (distinct from `AbilityClass`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `MovementPattern {PUSH,PULL,LEG,...}` is NOT a class enum (no STRIKE/CONTROL/MOBILITY members) so it does not trip the "second AbilityClass declaration = CI error" rule. Its ordinals 0/1/2 deliberately align with AbilityClass/target_stat (1:1:1 spine) but it is a distinct TYPE — never conflate.

**Control Manifest Rules (this layer)**:
- Required: return UNKNOWN explicitly on miss — never zero-default fallback to STRIKE.
- Required: declaration order is load-bearing — never reorder enum members.
- Guardrail: pure function, deterministic, no global state.

---

## Acceptance Criteria

*From GDD, scoped to this story:*

- [ ] **AC-02** `get_class_for_movement_pattern(PUSH(0)/PULL(1)/LEG(2))` → returns STRIKE(0)/CONTROL(1)/MOBILITY(2) respectively.
- [ ] **AC-03 (pattern-side)** unknown pattern → `UNKNOWN(3)` (never fabricated).
- [ ] **AC-13** all non-spine ordinals {CORE(3), CARDIO(4), FLEXIBILITY(5), COMPOUND(6), UNKNOWN_PATTERN(7)} → `UNKNOWN(3)`.

---

## Implementation Notes

*Derived from ADR-0007 + GDD Rule 4/4b/5 + Formula 1b:*

- **`MovementPattern` enum** (7+sentinel members): `{ PUSH=0, PULL=1, LEG=2, CORE=3, CARDIO=4, FLEXIBILITY=5, COMPOUND=6, UNKNOWN_PATTERN=7 }`. `LEG` is singular (matches entities.yaml). Place in a shared location (`src/core/movement_pattern.gd` `class_name MovementPattern`, OR embedded) — entities.yaml registration is a cross-system gate (systems-designer), not this story.
- **`pattern_map`**: only 3 spine rows `{PUSH→STRIKE, PULL→CONTROL, LEG→MOBILITY}`. Implement via `match` statement (NOT `const Dictionary` — GDScript `const Dictionary` is not truly immutable; `match` is cleaner and immutable). CORE/CARDIO/FLEXIBILITY/COMPOUND/UNKNOWN_PATTERN are NOT in the map.
- **`get_class_for_movement_pattern(pattern: int) -> int`** (Formula 1b): `match pattern: PUSH→0, PULL→1, LEG→2, _→3 (UNKNOWN)`. Independent entry point — does NOT call `get_class_for_exercise`.
- COMPOUND→UNKNOWN is design intent: compound exercises must have an explicit registry entry; callers must use `get_class_for_exercise`, not this pattern API, for compound lookups.

---

## Out of Scope

- **Story 001**: `get_class_for_exercise` id-lookup, registry schema, `_normalize`.
- **Story 003**: boot validation of `movement_pattern` field on registry entries.
- entities.yaml 7-member MovementPattern registration — cross-system gate (systems-designer).

---

## QA Test Cases

- **TC-002-01..03 Spine mapping (AC-02)**
  - When `get_class_for_movement_pattern(0/1/2)` → Then `0/1/2` (STRIKE/CONTROL/MOBILITY) respectively. Each asserted independently. LEG=2 confirms singular enum member.
- **TC-002-04 Unknown pattern → UNKNOWN (AC-03 pattern-side)**
  - When `get_class_for_movement_pattern(99)` → Then `3`. Edge: `-1`, `255`, MAX_INT all → `3`.
- **TC-002-05..09 Non-spine ordinals → UNKNOWN (AC-13)**
  - When `get_class_for_movement_pattern(p)` for p ∈ {3 CORE, 4 CARDIO, 5 FLEXIBILITY, 6 COMPOUND, 7 UNKNOWN_PATTERN} → Then each returns `3`.
  - COMPOUND(6): design intent — compound must use registry entry, not pattern API.
  - UNKNOWN_PATTERN(7): sentinel → UNKNOWN, no crash.
- **(ADVISORY) enum declaration order**: assert PUSH=0/PULL=1/LEG=2 ordinals to guard against silent ordinal shift.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/exercise_class_mapping/test_movement_pattern_lookup.gd` — must exist and pass
**Status**: [x] Created + passing (14 tests, GUT `test_` prefix so it actually runs — see note below)

> ⚠️ **GUT filename convention**: GUT default collects only `test_*.gd` (prefix), NOT
> `*_test.gd` (suffix). The original evidence path used the suffix form, which GUT silently
> skips ("Nothing was run" = phantom pass). Corrected to `test_` prefix. The same defect was
> found in Story 001's `registry_lookup_test.gd` (never ran + referenced an undeclared global
> type) and fixed here → renamed `test_registry_lookup.gd` with the preload SUT pattern.

---

## Dependencies

- Depends on: Story 001 (uses the autoload + AbilityClass ordinal convention; can be implemented in parallel after 001's scaffold)
- Unlocks: Story 003 (boot validation references MovementPattern ordinal range {0..7})

---

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 3/3 passing (AC-02, AC-03, AC-13 — all COVERED by automated unit tests)
**Deviations**:
- ADVISORY (test path): Test Evidence path corrected `movement_pattern_lookup_test.gd` → `test_movement_pattern_lookup.gd`. GUT default collects only `test_*.gd` (prefix); the `*_test.gd` suffix is silently skipped ("Nothing was run" = phantom pass).
- OUT OF SCOPE (valid): fixed Story 001's phantom test `registry_lookup_test.gd` → `test_registry_lookup.gd` + converted to preload SUT pattern (`const ECM := preload(...)` + `ECM.new()`). Story 001 referenced an undeclared global type `ExerciseClassMapping` (autoload not registered until Story 005, no class_name) → parse error; combined with the wrong filename it NEVER ran. Now Story 001's 16 tests actually execute + pass. Implementation code was already correct — only the test harness was broken.
**Test Evidence**: Logic — `tests/unit/exercise_class_mapping/test_movement_pattern_lookup.gd` (14 tests, GUT green). Combined gate: 1281 tests / 1280 pass / 1 pre-existing pending (AC-37, non-#10) / 0 fail. #10 dir: 2 scripts / 30 tests / 30 pass / 42 asserts.
**Code Review**: Complete — QL-TEST-COVERAGE ADEQUATE + LP-CODE-REVIEW APPROVED (full review mode, 2026-06-02).
**Follow-up (cross-epic, not #10)**: 2 other pre-existing phantom tests use the wrong `*_test.gd` suffix and never run — `tests/unit/loot/loot_rarity_formula_test.gd`, `tests/unit/state_machine/connect_for_initial_state_test.gd`. Recommend each owning epic rename to `test_*` prefix and verify they compile + pass.
