# Story 003: Calendar Formulas — DST-Robust Day Classification

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-006`, `TR-streak-007`
*(TR-006: "consecutive_day_classification — DST-robust via locked timezone offset + noon-anchored arithmetic"; TR-007: "local_calendar_date_from_utc Formula 3")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (drift-tolerant clock usage)
**ADR Decision Summary**: Calendar day classification uses noon-anchored arithmetic (midnight is ambiguous across DST boundaries). `local_calendar_date_from_utc(utc, tz_offset)` produces a stable YYYYMMDD integer. Two events are "consecutive days" if their date integers differ by exactly 1.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript int arithmetic only. No `Date` class needed. `Time.get_unix_time_from_system()` is UTC.

**Control Manifest Rules (Foundation layer)**:
- Required: Noon-anchored arithmetic (anchor = UTC + tz_offset, rounded to nearest noon)
- Forbidden: Using midnight as day boundary (DST-unsafe)

---

## Acceptance Criteria

- [x] **AC-ss-cal-1**: GIVEN `utc=1700000000`, `tz_offset=28800` (UTC+8), WHEN `local_calendar_date_from_utc(utc, tz_offset)` called, THEN returns stable YYYYMMDD integer for that local date.
- [x] **AC-ss-cal-2**: GIVEN two events in consecutive local days (e.g. Mon + Tue), WHEN `consecutive_day_classification(date_a, date_b)` called, THEN returns `true`.
- [x] **AC-ss-cal-3**: GIVEN DST spring-forward (clocks move from 23:59 to 01:00 skipping midnight), WHEN two events around that boundary classified, THEN noon-anchored arithmetic correctly identifies consecutive days.
- [x] **AC-ss-cal-4**: GIVEN same local day, WHEN `consecutive_day_classification` called, THEN returns `false` (same day ≠ consecutive).

---

## Implementation Notes

Formula 3 — local_calendar_date_from_utc:
```gdscript
func local_calendar_date_from_utc(utc: int, tz_offset_seconds: int) -> int:
    # Shift to local time, then anchor to noon of that day.
    var local: int = utc + tz_offset_seconds
    # Truncate to day, then add 12h to get noon
    var day_start: int = (local / 86400) * 86400
    var noon: int = day_start + 43200
    # Return as YYYYMMDD integer
    var dt: Dictionary = Time.get_datetime_dict_from_unix_time(noon)
    return dt["year"] * 10000 + dt["month"] * 100 + dt["day"]
```

Formula 2 — consecutive_day_classification:
```gdscript
func consecutive_day_classification(date_a: int, date_b: int) -> bool:
    # Dates are YYYYMMDD integers. Consecutive = differ by exactly 1 calendar day.
    # Simple approach: compare via date math (not raw subtraction — month boundaries).
    if date_b - date_a == 1:
        return true
    # Handle month boundaries by converting back to unix + comparing day diff
    return _days_between(date_a, date_b) == 1
```

---

## Out of Scope

- Story 002: drift gate that calls this
- Story 005: persistence write

---

## QA Test Cases

**AC-ss-cal-1** — Unit (table-driven)
- Given: known UTC timestamp + timezone offset
- When: `local_calendar_date_from_utc` called
- Then: returns expected YYYYMMDD integer (verified against known dates)

**AC-ss-cal-2** — Unit
- Given: consecutive day YYYYMMDD integers (e.g. 20240101, 20240102)
- When: `consecutive_day_classification` called
- Then: true

**AC-ss-cal-3** — Unit (DST edge case)
- Given: events on either side of DST spring-forward boundary
- When: classified
- Then: noon-anchored arithmetic returns correct consecutive result

**AC-ss-cal-4** — Unit
- Given: same YYYYMMDD integer for both
- When: classified
- Then: false

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/streak/test_calendar_formulas.gd` — must pass

**Status**: [x] Created — 6 test functions (cal-1/2/3/4 + month-boundary + negative-tz guard)

---

## Dependencies

- Depends on: Story 002 (calls these formulas)
- Unlocks: Story 004 (streak accumulation uses consecutive classification)

---

## Completion Notes

**Completed**: 2026-05-29
**Criteria**: 4/4 passing (0 deferred)
**Deviations**: None
**Test Evidence**: Logic unit test at `tests/unit/streak/test_calendar_formulas.gd` (6 tests). Added robustness fix beyond spec: `posmod` floor-to-day instead of integer-division truncation (correct for negative local timestamps); regression test included.
**Code Review**: Complete — APPROVED (0 BLOCKING; posmod negative-tz robustness fix applied post-review)
