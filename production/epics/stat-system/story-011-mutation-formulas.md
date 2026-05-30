# Story 011: Mutation Formulas F1 + F2 (VOLUME_TICK + PR_BREAKTHROUGH)

> **Epic**: Stat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-23 ✓ AC-24 ✓ AC-25 ✓)
**Deviations**: ADVISORY — `PR_BASE = 6.0` is PROVISIONAL pending ADR-0005 ratification (Q-A1 cross-validation); caller-computed model (F1/F2 owned by #9/#18, StatSystem holds the const single-source-of-truth only). Tests reference the consts, not literals
**Test Evidence**: Logic — `test_formula1_volume_tick.gd`, `test_formula2_pr_default.gd`, `test_formula2_pr_at_max.gd`
**Code Review**: Complete (Batch C) — CLEAN

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-012`
*(TR-stat-012: 6 derived formulas — VOLUME_TICK delta (F1) + PR_BREAKTHROUGH delta (F2))*

**ADR Governing Implementation**: ADR-0005 (Proposed ⚠️ — `PR_BASE` retune gated on ADR-005 Accepted); ADR-0006 Contract 11 (sync API, no `await`)
**ADR Decision Summary**: Formula 1 (VOLUME_TICK) is a pure routing + scale function — class_id determines which stat receives the delta (hard 1:1 mapping). Formula 2 (PR_BREAKTHROUGH) is provisional (PR_BASE=6.0 is a VS-tier mock pending ADR-005 Q-A1 cross-validation). Both compute a delta value that is then passed to `apply_stat_delta` — callers (#9 WorkoutStateTracker + #18 PR Detection) compute the delta, not StatSystem.

> ⚠️ ADR-0005 Proposed — Formula 2 `PR_BASE` is provisional. The formula is implemented as specified but tagged for retune after ADR-005 ratification. Story is READY (Formula 2 works with current provisional values; retune is a sprint task, not a blocker).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `pow(base, exp)` for diminishing factor. GDScript `float` division. `clamp(m, 0.0, 2.0)` for pr_magnitude ceiling.

**Control Manifest Rules (Core layer)**:
- Required: VOLUME_TICK class routing is hard 1:1 — push→STR, pull→DEX, leg→VIT — no cross-routing (INV cross-routing matrix)
- Required: PR_BREAKTHROUGH delta must clamp `pr_magnitude` to [0.0, 2.0] before applying (EC-36 anomalous input guard)
- Required: Formula 2 tagged as PROVISIONAL — `PR_BASE = 6.0` const must be retuneable without schema bump

---

## Acceptance Criteria

- [ ] **AC-23** — GIVEN Stat System Ready, STR=DEX=VIT=10, VOLUME_TICK_BASE=0.05, WHEN #9 path calls `apply_stat_delta(StatId.STR, StatSource.VOLUME_TICK, 0.05)` (class_id=PUSH already routed by #10 to STR), THEN STR=10.05, DEX=10.0 unchanged, VIT=10.0 unchanged, AND `stat_changed(STR, 10.0, 10.05, VOLUME_TICK, false)` emits.
- [ ] **AC-24** — GIVEN STR=12.0, PR_BASE=6.0, PR_DIMINISH_EXP=2.0, MAX_STAT_VALUE=999, WHEN `apply_stat_delta(StatId.STR, StatSource.PR_BREAKTHROUGH, 0.500)` is called (caller pre-computed delta from `pr_magnitude=0.0833` via Formula 2: `6.0 × 0.0833 × (1-(12/999)^2) ≈ 0.500`), THEN STR ≈ 12.5 (±0.001 tolerance).
- [ ] **AC-25** — GIVEN STR=999 (MAX_STAT_VALUE), WHEN caller computes `pr_delta = PR_BASE × pr_magnitude × diminishing_factor(999)` = 0.0 exactly (INV-2: diminishing_factor(MAX_STAT_VALUE)=0), AND calls `apply_stat_delta(STR, PR_BREAKTHROUGH, 0.0)` (delta=0 is valid per EC-10), THEN returns `true`, no push_error, STR unchanged at 999.

---

## Implementation Notes

*From GDD Formulas 1, 2 + EC-10 + EC-13 + EC-36:*

**Caller-computed model**: StatSystem does NOT own Formula 1 or 2 computation. Callers (#9 WorkoutStateTracker for VOLUME_TICK; #18 PR Detection for PR_BREAKTHROUGH) compute the delta and call `apply_stat_delta(stat_id, source, delta)`. StatSystem's validation layer (Story 002) then enforces source/stat allow-list.

The formulas are **documented here for the callers to implement**:

**Formula 1 — VOLUME_TICK delta** (implemented in #9 WorkoutStateTracker):
```gdscript
# class_weight is 1.0 for matching stat, 0.0 for others
volume_tick_delta = VOLUME_TICK_BASE * class_weight(class_id, target_stat)
# Class routing (hard mapping, no cross-routing):
# PUSH → STR: 1.0, DEX: 0.0, VIT: 0.0
# PULL → STR: 0.0, DEX: 1.0, VIT: 0.0
# LEG  → STR: 0.0, DEX: 0.0, VIT: 1.0
```

**Formula 2 — PR_BREAKTHROUGH delta** (implemented in #18 PR Detection):
```gdscript
pr_magnitude = clamp((new_1rm - old_1rm) / old_1rm, 0.0, 2.0)  # EC-36 guard
diminishing_factor = 1.0 - pow(current_stat / MAX_STAT_VALUE, PR_DIMINISH_EXP)
pr_delta = PR_BASE * pr_magnitude * diminishing_factor
# Then caller calls: StatSystem.apply_stat_delta(stat_id, StatSource.PR_BREAKTHROUGH, pr_delta)
```

**For testing purposes** (these tests use StatSystem.apply_stat_delta with pre-computed delta):
- AC-23 passes `0.05` (VOLUME_TICK_BASE × 1.0 routing weight for PUSH → STR)
- AC-24 passes `0.500` (pre-computed by test, matching Formula 2 worked example)
- AC-25 passes `0.0` (diminishing_factor(999) = 0 → delta = 0)

**VS-tier mock**: For VS testing without #9/#18 implemented, use a debug helper that calls `apply_stat_delta` directly with computed delta values. This is the test pattern used in these ACs.

---

## Out of Scope

- #9 WorkoutStateTracker implementation (owns Formula 1 caller side)
- #18 PR Detection implementation (owns Formula 2 caller side)
- Story 010: Derived stat formulas F3-F6 (compute output stats; Formulas 1+2 compute input deltas)
- Story 012: Cross-knob invariants for `PR_BASE`, `VOLUME_TICK_BASE` ranges

---

## QA Test Cases

**Story Type**: Logic (all unit tests, pure math)

- **AC-23**: VOLUME_TICK class routing (PUSH → STR)
  - Given: STR=DEX=VIT=10; VOLUME_TICK_BASE=0.05
  - When: `apply_stat_delta(STR, VOLUME_TICK, 0.05)` (PUSH→STR pre-routed by caller)
  - Then: STR=10.05; DEX=10.0; VIT=10.0; `stat_changed(STR, 10.0, 10.05, VOLUME_TICK, false)` emits once
  - Edge cases: Same call with `apply_stat_delta(DEX, VOLUME_TICK, 0.0)` (PUSH→DEX cross-route attempt, delta=0 per 0.0 weight → EC-10 valid but no change); `apply_stat_delta(DEX, VOLUME_TICK, 0.05)` → should succeed (PULL→DEX routing)

- **AC-24**: PR_BREAKTHROUGH worked example
  - Given: STR=12.0; constants PR_BASE=6.0, PR_DIMINISH_EXP=2.0, MAX_STAT_VALUE=999
  - When: Compute delta = `6.0 * 0.0833 * (1-(12/999)^2) ≈ 0.500`; call `apply_stat_delta(STR, PR_BREAKTHROUGH, 0.500)`
  - Then: STR ≈ 12.5 (assert within ±0.001 tolerance)
  - Edge cases: PR_BASE default value (6.0) must match const in stat_system.gd — test asserts formula uses the const not a hardcoded literal

- **AC-25**: PR at MAX_STAT_VALUE (delta=0, EC-10 + INV-2)
  - Given: STR=999
  - When: `apply_stat_delta(STR, PR_BREAKTHROUGH, 0.0)` (delta=0 — diminishing=0 at MAX)
  - Then: Returns true; STR=999.0 (unchanged); no push_error; `stat_changed` fires with old==new (EC-10 — delta=0 is legal, signal still fires)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_formula1_volume_tick.gd`, `test_formula2_pr_default.gd`, `test_formula2_pr_at_max.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (atomic write sequence — computed delta is passed through this pipeline), Story 007 (anti-decay / clamping fires for delta boundary cases)
- Unlocks: Story 012 (cross-knob invariants include PR_BASE + VOLUME_TICK_BASE safe ranges)
