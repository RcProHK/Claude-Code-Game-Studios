# Story 005: Atomic Persistence Write — streak.* Namespace

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-008`
*(Requirement text: "Atomic 2-write order: (streak.streak_count, N, flush=false) then (streak.last_workout_date_local, date, flush=true)")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (PersistenceLayer integration) — secondary: ADR-0003 (Proposed ⚠️) governs `streak.*` namespace policy
**ADR Decision Summary**: Two writes in fixed order: count first (non-critical), date second (critical flush=true — date is the recovery anchor). If flush fails → corrupt path. Namespace `streak.*` per GDD Rule 12.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `PersistenceLayer.write(key, val, flush)` API (Stories 002+003 implemented). `flush=true` for critical path (date write).

**Control Manifest Rules (Foundation layer)**:
- Required: 2-write order — count first (non-critical), date second (critical flush=true)
- Required: `streak.*` namespace prefix on all keys

---

## Acceptance Criteria

- [x] **AC-ss-persist-1**: GIVEN successful workout, WHEN streak write executes, THEN `PersistenceLayer.write("streak.streak_count", N, false)` called BEFORE `PersistenceLayer.write("streak.last_workout_date_local", date, true)`.
- [x] **AC-ss-persist-2**: GIVEN second flush (date write) fails, WHEN `critical_save_failed` emitted, THEN streak state transitions to Failed; `streak_persistence_failed` signal emitted.
- [x] **AC-ss-persist-3**: GIVEN `record_today_workout()` called twice in same day, WHEN second call, THEN idempotent — streak count NOT incremented again; no duplicate write.

---

## Implementation Notes

```gdscript
const KEY_STREAK_COUNT: String = "streak.streak_count"
const KEY_LAST_WORKOUT_DATE: String = "streak.last_workout_date_local"

func _persist_streak(new_count: int, local_date: int) -> void:
    # Write order locked per TR-streak-008: count first (non-critical), date second (critical).
    PersistenceLayer.write(KEY_STREAK_COUNT, new_count, false)
    var ok: bool = PersistenceLayer.write(KEY_LAST_WORKOUT_DATE, local_date, true)
    if not ok:
        _substate = Substate.FAILED
        streak_persistence_failed.emit("FLUSH_FAILED", KEY_LAST_WORKOUT_DATE)
        return
    _streak_count = new_count
    _last_workout_date_local = local_date
```

Idempotency: compare local_date of incoming event with `_last_workout_date_local` — if same, skip.

---

## Out of Scope

- Story 003: calendar formula that produces `local_date`
- Story 006: Failed state handling (sticky single-emit)

---

## QA Test Cases

**AC-ss-persist-1** — Integration (write-order spy)
- Given: MockPersistenceLayer with write_spy
- When: `_persist_streak(3, 20240101)` called
- Then: write_log[0].key == "streak.streak_count"; write_log[1].key == "streak.last_workout_date_local"

**AC-ss-persist-2** — Integration
- Given: MockPersistenceLayer.fail_next_store_string = true (second write fails)
- When: `_persist_streak` executes
- Then: substate = FAILED; `streak_persistence_failed` emitted

**AC-ss-persist-3** — Integration (idempotency)
- Given: same local_date as `_last_workout_date_local`
- When: `_on_workout_completed` called again
- Then: write_log.size() == 0 (no duplicate write)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/streak/test_atomic_persistence_write.gd` — must pass

**Status**: [x] Created — 4 test functions (persist-1 write order, persist-2 date-fail + count-fail, persist-3 idempotent)

---

## Dependencies

- Depends on: Story 003 (calendar date), PersistenceLayer Stories 002+003 Complete ✅
- Unlocks: Story 006 (failed state uses signals from this)

---

## Completion Notes

**Completed**: 2026-05-29
**Criteria**: 3/3 passing (0 deferred)
**Deviations**:
- ADVISORY: secondary ADR-0003 (Proposed) governs the `streak.*` namespace policy; proceeded because the primary governing ADR-0006 Contract 9 is Accepted and the namespace prefix is locked by GDD Rule 12. Re-validate when ADR-0003 ratifies.
- `_persist_streak` introduced a `_persistence` DI seam (untyped — see code review note below) and was wired into `_on_workout_completed` via `record_today_workout` (computes local date, idempotency, consecutive-day count, then 2-write).
**Test Evidence**: Integration test at `tests/integration/streak/test_atomic_persistence_write.gd` (4 tests incl. count-write-failure variant added post-review)
**Code Review**: Complete — APPROVED. Fixes applied: untyped DI seam (BLOCKING — typed `Node` seam fails GDScript compile-time member check); count-write return value now checked (WARNING-1); count-write-failure regression test added.
