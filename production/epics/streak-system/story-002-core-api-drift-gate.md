# Story 002: Core API — `_on_workout_completed` + Drift Gate

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-001`
*(Requirement text: "Single API entry `_on_workout_completed(completed_at_utc)` with drift gate `_passes_drift_gate` using WALL_CLOCK_DRIFT_TOLERANCE_SECONDS")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (clock-drift TTL) — is_expired() used for drift detection
**ADR Decision Summary**: `completed_at_utc` is validated via drift gate: if |completed_at_utc - now_utc| > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS (300s), event is rejected as potentially fabricated. Pillar 1 anti-fabrication.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_unix_time_from_system()` for now_utc. Int arithmetic.

**Control Manifest Rules (Foundation layer)**:
- Required: Drift gate rejects events with |completed_at_utc - now| > 300s
- Forbidden: No direct `PersistenceLayer.write()` from outside StreakSystem (closed API)

---

## Acceptance Criteria

- [x] **AC-ss-api-1**: GIVEN `completed_at_utc = now ± 150s`, WHEN `_on_workout_completed(completed_at_utc)` called, THEN drift gate PASSES; streak logic proceeds.
- [x] **AC-ss-api-2**: GIVEN `completed_at_utc = now + 600s` (future, suspicious), WHEN `_on_workout_completed(completed_at_utc)` called, THEN drift gate REJECTS; `streak_persistence_failed("DRIFT_GATE_REJECTED", "")` emitted; streak NOT incremented.
- [x] **AC-ss-api-3**: GIVEN StreakSystem in BOOTING substate, WHEN `_on_workout_completed` called, THEN event deferred to `_deferred_events`; processed after Ready.

---

## Implementation Notes

```gdscript
const WALL_CLOCK_DRIFT_TOLERANCE_SECONDS: int = PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS

signal streak_persistence_failed(error_code: String, key: String)

func _on_workout_completed(completed_at_utc: int) -> void:
    if _substate == Substate.BOOTING:
        _deferred_events.append(func(): _on_workout_completed(completed_at_utc))
        return
    if not _passes_drift_gate(completed_at_utc):
        streak_persistence_failed.emit("DRIFT_GATE_REJECTED", "")
        return
    # ... proceed to Story 003 calendar classification ...

func _passes_drift_gate(completed_at_utc: int) -> bool:
    var delta: int = abs(int(Time.get_unix_time_from_system()) - completed_at_utc)
    return delta <= WALL_CLOCK_DRIFT_TOLERANCE_SECONDS
```

---

## Out of Scope

- Story 003: `consecutive_day_classification` (calendar logic)
- Story 005: persistence write

---

## QA Test Cases

**AC-ss-api-1** — Unit
- Given: `completed_at_utc = now - 100`
- When: `_on_workout_completed(now-100)` called
- Then: drift gate passes; no error emitted

**AC-ss-api-2** — Unit
- Given: `completed_at_utc = now + 600`
- When: called
- Then: `streak_persistence_failed("DRIFT_GATE_REJECTED","")` emitted; streak unchanged

**AC-ss-api-3** — Unit
- Given: substate = BOOTING
- When: `_on_workout_completed` called
- Then: added to `_deferred_events`; size == 1

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/streak/test_core_api_drift_gate.gd` — must pass

**Status**: [x] Created — 4 test functions covering all 3 ACs + boundary guard
- `test_drift_gate_passes_for_recent_timestamp` (AC-ss-api-1)
- `test_drift_gate_rejects_future_timestamp` (AC-ss-api-2)
- `test_drift_gate_boundary_and_past_direction` (off-by-one + abs both directions)
- `test_booting_substate_defers_event` (AC-ss-api-3)

---

## Dependencies

- Depends on: Story 001 (state machine + WALL_CLOCK constant)
- Unlocks: Story 003 (calendar classification called from this)

---

## Completion Notes

**Completed**: 2026-05-29
**Criteria**: 3/3 passing (0 deferred)
**Deviations**: ADVISORY — const literal `= 300` used instead of `= PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS`. Reason: PersistenceLayer is an autoload singleton (no class_name), unavailable at parse-time for const initializer. Pattern: `const = 300` + `_ready()` runtime sync assert, mirrors GameStateMachine Invariant 7 (line 680). Functionally equivalent, architecturally correct.
**Story 003 follow-ups**: (1) deferred event drain→replay drift coverage (WARNING-3); (2) GDD EC-02 `_drift_rejected_count` + `push_warning` telemetry; (3) error_code direction split (future vs stale) — systems-designer decision.
**Test Evidence**: Logic unit test at `tests/unit/streak/test_core_api_drift_gate.gd` (4 tests, all ACs + boundary)
**Code Review**: Complete — APPROVED (BLOCKING #1 const parse-time fix; 2 boundary tests added post-review)
