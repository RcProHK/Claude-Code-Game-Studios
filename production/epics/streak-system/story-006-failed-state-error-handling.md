# Story 006: Failed State + Error Handling (Sticky Single-Emit)

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-009`, `TR-streak-010`
*(TR-009: "Failed state sticky single-emit (streak_persistence_failed not re-emitted)"; TR-010: "Namespace streak.* filter on critical_save_failed")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (PersistenceLayer error signals)
**ADR Decision Summary**: Failed substate is sticky — `streak_persistence_failed` emits exactly once; subsequent flush failures in Failed substate are silent. Listen to `PersistenceLayer.critical_save_failed` and filter for `streak.*` key prefix only.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal connection in `_ready()`. PersistenceLayer signal already declared.

**Control Manifest Rules (Foundation layer)**:
- Forbidden: Never auto-recover from Failed substate without session restart
- Required: `streak.*` namespace filter on PersistenceLayer.critical_save_failed

---

## Acceptance Criteria

- [x] **AC-ss-fail-1**: GIVEN Failed substate entered, WHEN 5 subsequent `_persist_streak` calls, THEN `streak_persistence_failed` emits exactly once total (sticky).
- [x] **AC-ss-fail-2**: GIVEN PersistenceLayer emits `critical_save_failed("QUOTA_EXHAUSTED", "stat.atk")` (different namespace), WHEN StreakSystem handler receives it, THEN ignored (no streak state change).
- [x] **AC-ss-fail-3**: GIVEN PersistenceLayer emits `critical_save_failed("FLUSH_FAILED", "streak.last_workout_date_local")`, WHEN handler receives it, THEN StreakSystem transitions to Failed.

---

## Implementation Notes

```gdscript
var _persistence_failed_emitted: bool = false

func _ready() -> void:
    PersistenceLayer.critical_save_failed.connect(_on_persistence_failed)

func _on_persistence_failed(error_code: String, key: String) -> void:
    # TR-streak-010: namespace filter — only streak.* keys are our concern
    if not key.begins_with("streak."):
        return
    if _substate != Substate.FAILED:
        _substate = Substate.FAILED
    # TR-streak-009: sticky single-emit
    if not _persistence_failed_emitted:
        _persistence_failed_emitted = true
        streak_persistence_failed.emit(error_code, key)
```

---

## Out of Scope

- Story 005: persistence write that triggers this
- Backoff recovery (lower priority, deferred)

---

## QA Test Cases

**AC-ss-fail-1** — Unit
- Given: Failed substate + `_persistence_failed_emitted=true`
- When: another error fires
- Then: `streak_persistence_failed` NOT emitted again; total emit count stays 1

**AC-ss-fail-2** — Unit
- Given: `critical_save_failed("QUOTA_EXHAUSTED", "stat.atk")`
- When: handler called
- Then: substate unchanged; no signal emitted

**AC-ss-fail-3** — Unit
- Given: `critical_save_failed("FLUSH_FAILED", "streak.last_workout_date_local")`
- When: handler called
- Then: substate = FAILED; `streak_persistence_failed` emitted once

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/streak/test_failed_state_error_handling.gd` — must pass

**Status**: [x] Created — 4 test functions (fail-1 sticky, fail-2 namespace ignore, fail-3 streak.* → FAILED, + workout-after-failed no-reemit)

---

## Dependencies

- Depends on: Story 001 (state machine), Story 005 (triggers errors)
- Unlocks: Story 008 (drift constant consistency)

---

## Completion Notes

**Completed**: 2026-05-29
**Criteria**: 3/3 passing (0 deferred)
**Deviations**: `_enter_failed` is a shared sticky-emit helper used by both Story 005 flush-failure and Story 006 external `critical_save_failed`. It is an intentional out-of-band transition (bypasses `_transition_to` LEGAL_ARCS because persistence failures can occur in any substate) but now emits `substate_changed` so the entry is observable. LEGAL_ARCS remains the contract for normal-flow `_transition_to` (Story 001 `READY→FAILED` illegal test unaffected).
**Test Evidence**: Logic unit test at `tests/unit/streak/test_failed_state_error_handling.gd` (4 tests incl. workout-after-failed no-reemit added post-review)
**Code Review**: Complete — APPROVED. Fixes applied: `_enter_failed` now emits substate_changed (BLOCKING-2 silent-transition concern); `_on_workout_completed` early-returns when FAILED (WARNING-2 drift-reject spam); regression test added.
