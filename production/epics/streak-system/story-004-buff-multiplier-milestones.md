# Story 004: Buff Multiplier Formula + Milestone Thresholds

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-005`, `TR-streak-011`
*(TR-005: "loot_rarity_modifier_step_curve Formula 1 — monotone non-decreasing, capped at 2.00"; TR-011: "Milestone gates ascending + no-duplicate + bounded invariant")*

**ADR Governing Implementation**: ADR: N/A — pure formula, no architectural pattern required (data-driven config)
**ADR Decision Summary**: N/A — milestone_thresholds is data-driven config. Buff multiplier formula is pure math over threshold steps {1,7,14,30,60,90}. Capped at 2.00.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript float arithmetic. `MILESTONE_THRESHOLDS` array constant.

**Control Manifest Rules (Foundation layer)**:
- Required: Milestone thresholds in ascending order, no duplicates (runtime assert)
- Required: Buff multiplier non-decreasing (Invariant — `MILESTONE_THRESHOLDS[i] < MILESTONE_THRESHOLDS[i+1]`)

---

## Acceptance Criteria

- [x] **AC-ss-buff-1**: GIVEN `streak_count = 0`, WHEN `get_streak_buff_multiplier()` called, THEN returns `1.0` (baseline, no bonus).
- [x] **AC-ss-buff-2**: GIVEN `streak_count = 7` (1-week milestone), WHEN `get_streak_buff_multiplier()` called, THEN returns expected step value; GIVEN `streak_count = 90`, THEN returns `2.0` (cap).
- [x] **AC-ss-buff-3**: GIVEN `MILESTONE_THRESHOLDS = [1,7,14,30,60,90]`, WHEN invariants checked at boot, THEN ascending + no-duplicate + bounded assertions pass.
- [x] **AC-ss-buff-4**: GIVEN `streak_count` between milestones (e.g. 10), WHEN `get_streak_buff_multiplier()` called, THEN returns value for most recent passed milestone (step function, not interpolated).

---

## Implementation Notes

```gdscript
const MILESTONE_THRESHOLDS: Array[int] = [1, 7, 14, 30, 60, 90]
const MILESTONE_MULTIPLIERS: Array[float] = [1.1, 1.25, 1.4, 1.6, 1.8, 2.0]
const MAX_BUFF_MULTIPLIER: float = 2.0

func get_streak_buff_multiplier() -> float:
    var count: int = _streak_count
    var result: float = 1.0
    for i in range(MILESTONE_THRESHOLDS.size()):
        if count >= MILESTONE_THRESHOLDS[i]:
            result = MILESTONE_MULTIPLIERS[i]
        else:
            break
    return min(result, MAX_BUFF_MULTIPLIER)

func _assert_milestone_invariants() -> void:
    for i in range(MILESTONE_THRESHOLDS.size() - 1):
        assert(MILESTONE_THRESHOLDS[i] < MILESTONE_THRESHOLDS[i+1],
            "Milestone thresholds must be strictly ascending")
        assert(MILESTONE_MULTIPLIERS[i] <= MILESTONE_MULTIPLIERS[i+1],
            "Multipliers must be non-decreasing")
```

---

## Out of Scope

- Story 007: CI caller whitelist (who may call `get_streak_buff_multiplier()`)

---

## QA Test Cases

**AC-ss-buff-1** — Unit
- Given: `_streak_count = 0`
- When: `get_streak_buff_multiplier()` called
- Then: returns 1.0

**AC-ss-buff-2** — Unit (table-driven)
- Given: streak_count ∈ {1,7,14,30,60,90}
- When: `get_streak_buff_multiplier()` called
- Then: returns corresponding MILESTONE_MULTIPLIERS value; at 90 = 2.0

**AC-ss-buff-3** — Unit
- Given: MILESTONE_THRESHOLDS array
- When: invariants checked
- Then: all ascending + bounded assertions pass

**AC-ss-buff-4** — Unit
- Given: `_streak_count = 10` (between milestones 7 and 14)
- When: called
- Then: returns MILESTONE_MULTIPLIERS[1] (7-day value, not interpolated)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/streak/test_buff_multiplier_milestones.gd` — must pass

**Status**: [x] Created — 5 test functions (buff-1/2/3/4 + cap-above-last-milestone)

---

## Dependencies

- Depends on: Story 001 (autoload structure)
- Unlocks: Story 007 (CI caller whitelist for this method)

---

## Completion Notes

**Completed**: 2026-05-29
**Criteria**: 4/4 passing (0 deferred)
**Deviations**: None
**Test Evidence**: Logic unit test at `tests/unit/streak/test_buff_multiplier_milestones.gd` (5 tests). `_assert_milestone_invariants()` invoked from `_assert_knob_invariants()` at boot.
**Code Review**: Complete — APPROVED (0 BLOCKING / 0 WARNING)
