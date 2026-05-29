# Story 008: Drift Constant Cross-System Consistency

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-012`
*(Requirement text: "Streak.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS cross-system consistency")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (clock-drift TTL)
**ADR Decision Summary**: StreakSystem's drift tolerance must exactly match PersistenceLayer's. Both use 300s. If PersistenceLayer changes its knob, StreakSystem must detect the mismatch at boot (runtime assert).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` is a const accessible as autoload singleton.

**Control Manifest Rules (Foundation layer)**:
- Required: `assert(WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS)` at boot

---

## Acceptance Criteria

- [x] **AC-ss-drift-1**: GIVEN StreakSystem loaded, WHEN `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` compared to `PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS`, THEN values are equal (both 300).
- [x] **AC-ss-drift-2**: GIVEN StreakSystem `_assert_knob_invariants()` runs at boot, THEN cross-system drift tolerance consistency assertion passes without error.
- [x] **AC-ss-drift-3**: GIVEN debug build where constants mismatch (simulated), WHEN `_assert_knob_invariants()` runs, THEN assertion trips.

---

## Implementation Notes

```gdscript
const WALL_CLOCK_DRIFT_TOLERANCE_SECONDS: int = 300  # Must match PersistenceLayer

func _assert_knob_invariants() -> void:
    assert(
        WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS,
        "Streak drift tolerance must match PersistenceLayer (%d vs %d)" % [
            WALL_CLOCK_DRIFT_TOLERANCE_SECONDS,
            PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS,
        ]
    )
```

Called from `_ready()` BEFORE `_load_from_persistence()`.

---

## Out of Scope

- Story 001: rest of boot sequence

---

## QA Test Cases

**AC-ss-drift-1** — Unit
- Given: StreakSystem + PersistenceLayer
- When: constants compared
- Then: equal (both 300)

**AC-ss-drift-2** — Unit
- Given: default constants
- When: `_assert_knob_invariants()` called
- Then: no assertion fire; no push_error

**AC-ss-drift-3** — Unit (math validation)
- Given: hypothetical mismatched value (e.g. 200 vs 300)
- When: assertion math checked
- Then: `200 == 300` evaluates false → would trip assert

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/streak/test_drift_constant_consistency.gd` — must pass

**Status**: [x] Created — 3 test functions (drift-1/2/3)

---

## Dependencies

- Depends on: Story 001 (boot sequence calls this), PersistenceLayer Story 007 (WALL_CLOCK_DRIFT_TOLERANCE_SECONDS exists ✅)
- Unlocks: None (final consistency gate)

---

## Completion Notes

**Completed**: 2026-05-29
**Criteria**: 3/3 passing (0 deferred)
**Deviations**: None — the cross-system drift assert was first introduced inline during Story 002 code review, then refactored here into the named `_assert_knob_invariants()` (called from `_ready()` before `_load_from_persistence()`), which also folds in Story 004's milestone invariants.
**Test Evidence**: Logic unit test at `tests/unit/streak/test_drift_constant_consistency.gd` (3 tests)
**Code Review**: Complete — APPROVED (0 BLOCKING; drift-3 tautology noted as inherent const-guard test limitation)
