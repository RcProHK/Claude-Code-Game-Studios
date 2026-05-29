# Story 012: Rule 5.5 Weekly Tick Replay

> **Epic**: GameStateMachine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/game-state-machine.md`
**Requirement**: `TR-gsm-012`
*(Requirement text: "Rule 5.5 weekly tick missed-window replay — missed_count = floor((now - _last_weekly_tick_unix) / WEEKLY_TICK_INTERVAL_SECONDS) clamped to MAX_WEEKLY_TICK_CATCHUP = 8")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (clock-drift TTL) + Contract 8 (MAX_WEEKLY_TICK_CATCHUP = 8 knob)
**ADR Decision Summary**: At boot, compute missed weekly ticks using `PersistenceLayer.is_expired()` helper. Clamp catchup to `MAX_WEEKLY_TICK_CATCHUP = 8` (prevent infinite loop on months-long absence). Emit `weekly_tick_catchup_capped(missed_count, capped_at)` if clamped.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_unix_time_from_system()` for current time. `floor()` for integer division.

**Control Manifest Rules (Foundation layer)**:
- Required: `MAX_WEEKLY_TICK_CATCHUP ≤ 52` (ADR-0006 Contract 8 Invariant 6)

---

## Acceptance Criteria

- [ ] **AC-gsm-weekly-1**: GIVEN `_last_weekly_tick_unix` = 3 weeks ago, WHEN Rule 5.5 runs, THEN `missed_count = 3`; 3 weekly-tick events processed.
- [ ] **AC-gsm-weekly-2**: GIVEN `_last_weekly_tick_unix` = 20 weeks ago, WHEN Rule 5.5 runs, THEN `missed_count` clamped to `MAX_WEEKLY_TICK_CATCHUP = 8`; `weekly_tick_catchup_capped(20, 8)` emitted.
- [ ] **AC-gsm-weekly-3**: GIVEN `_last_weekly_tick_unix` = yesterday (< 1 week), WHEN Rule 5.5 runs, THEN `missed_count = 0`; no tick events fired.

---

## Implementation Notes

```gdscript
const WEEKLY_TICK_INTERVAL_SECONDS: int = 7 * 86400  # 604800
const MAX_WEEKLY_TICK_CATCHUP: int = 8
signal weekly_tick_catchup_capped(missed_count: int, capped_at: int)

func _run_rule5_5_weekly_tick_replay() -> void:
    var last_tick: int = PersistenceLayer.read("gsm._last_weekly_tick_unix")
    if last_tick == null: return
    var now: int = int(Time.get_unix_time_from_system())
    var missed: int = int(floor((now - last_tick) / WEEKLY_TICK_INTERVAL_SECONDS))
    if missed <= 0: return
    if missed > MAX_WEEKLY_TICK_CATCHUP:
        weekly_tick_catchup_capped.emit(missed, MAX_WEEKLY_TICK_CATCHUP)
        missed = MAX_WEEKLY_TICK_CATCHUP
    for i in range(missed):
        _fire_weekly_tick()
```

---

## Out of Scope

- Story 011: Basic Rule 5 (this runs after it as Rule 5.5)

---

## QA Test Cases

**AC-gsm-weekly-1** — Unit
- Given: MockPersistenceLayer with last_tick = 3 weeks ago
- When: Rule 5.5 runs
- Then: 3 weekly ticks fired

**AC-gsm-weekly-2** — Unit
- Given: last_tick = 20 weeks ago
- When: Rule 5.5 runs
- Then: clamped to 8; signal emitted with (20, 8)

**AC-gsm-weekly-3** — Unit
- Given: last_tick = yesterday
- When: Rule 5.5 runs
- Then: 0 ticks fired

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/state_machine/test_weekly_tick_replay.gd` — must pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 011 (boot reconciliation framework)
- Unlocks: Mirror Moment system (#29) eventually uses weekly ticks
