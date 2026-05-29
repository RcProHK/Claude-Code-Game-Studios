# Story 007: Clock-Drift TTL Formula — `is_expired()` Helper

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-009`
*(Requirement text: "Clock-drift TTL helper `is_expired(anchor_unix, ttl_seconds, anchor_monotonic_ms)` with `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS=300`")*

**ADR Governing Implementation**: ADR-0006 Contract 9 (Wall-Clock TTL with Clock-Drift Tolerance)
**ADR Decision Summary**: `is_expired()` compares wall-clock delta against TTL, with monotonic fallback if |wall_delta - mono_delta| > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS (300s). Pure function — no side effects. `anchor_monotonic_ms` is session-scoped only; cross-session callers MUST pass 0.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_msec()` returns int64 (NOT uint32) — no 24.8-day wraparound. `Time.get_unix_time_from_system()` for wall-clock. Session-scoped monotonic resets to 0 on process restart.

**Control Manifest Rules (Foundation layer)**:
- Required: drift comparison at ms precision: `abs(wall_delta * 1000 - monotonic_delta_ms) > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS * 1000`
- Required: cross-session anchor guard: if `now_mono < anchor_mono` → fallback to wall-clock (push_error)
- Required: `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` range 60..3600 (runtime assert at boot)

---

## Acceptance Criteria

- [ ] **AC-14**: GIVEN mock `IClock` with controllable wall-clock + monotonic, WHEN 6-row Formula 1 behaviour matrix executed, THEN return value matches expected per row; cache snapshot byte-identical before/after each call (pure function — no mutation).

  | Row | Scenario | wall_delta | mono_delta_ms | Expected return |
  |-----|----------|-----------|---------------|-----------------|
  | 1 | Normal not-expired (wall=100s, ttl=86400s) | 100s | 100000ms | `false` |
  | 2 | Normal expired (wall=90000s, ttl=86400s) | 90000s | 90000000ms | `true` |
  | 3 | NTP +600s drift (wall_delta=700s, mono=100s, ttl=86400s) | 700s | 100000ms | `false` (trust mono: 100000ms < 86400000ms) |
  | 4 | DST +3600s (wall=3700s, mono=100s, ttl=86400s) | 3700s | 100000ms | `false` (trust mono) |
  | 5 | Clock rollback -86400s (wall=-86300s, mono=100s, ttl=86400s) | -86300s | 100000ms | `false` (trust mono) |
  | 6 | No monotonic anchor (wall=90000s, ttl=86400s, mono omitted=0) | 90000s | N/A | `true` (wall only) |

- [ ] **AC-14b**: GIVEN `anchor_unix=0` (uninitialized / clock not yet set) AND `anchor_monotonic_ms=0` (no monotonic anchor), WHEN `is_expired(0, 86400)` called with `now_unix < anchor_unix` (i.e., negative `wall_delta`), THEN function returns `false` AND emits `push_warning` (not expired — uninitialized clock treated conservatively).
- [ ] **AC-14c**: GIVEN `ttl_seconds=0` AND `wall_delta=1` (1 second elapsed), WHEN `is_expired(anchor_unix, 0)`, THEN returns `true` (any elapsed time > 0s TTL is expired). GIVEN `ttl_seconds=0` AND `wall_delta=0` (exactly at anchor), THEN returns `false` (strict greater-than, not ≥).

---

## Implementation Notes

*From GDD Formula 1 + ADR-0006 Contract 9:*

```gdscript
const WALL_CLOCK_DRIFT_TOLERANCE_SECONDS: int = 300

func is_expired(anchor_unix: int, ttl_seconds: int, anchor_monotonic_ms: int = 0) -> bool:
    var now_unix: int = int(Time.get_unix_time_from_system())
    var wall_delta: int = now_unix - anchor_unix
    # Guard: negative wall_delta + no monotonic (clock uninitialized)
    if wall_delta < 0 and anchor_monotonic_ms == 0:
        push_warning("is_expired: negative wall_delta — treating as not-expired")
        return false
    if anchor_monotonic_ms > 0:
        var now_mono: int = Time.get_ticks_msec()
        # Cross-session guard
        if now_mono < anchor_monotonic_ms:
            push_error("is_expired: cross-session anchor_monotonic_ms — fallback to wall-clock")
            return wall_delta > ttl_seconds
        var mono_delta_ms: int = now_mono - anchor_monotonic_ms
        # ms-precision comparison
        if abs(wall_delta * 1000 - mono_delta_ms) > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS * 1000:
            return mono_delta_ms > ttl_seconds * 1000
    return wall_delta > ttl_seconds
```

Runtime boot assert (called from `_assert_knob_invariants()`):
```gdscript
assert(WALL_CLOCK_DRIFT_TOLERANCE_SECONDS >= 60 and WALL_CLOCK_DRIFT_TOLERANCE_SECONDS <= 3600)
```

---

## Out of Scope

- Cross-system callers (GymSys 35-day pruning, GSM weekly tick) — those use this helper in their own stories

---

## QA Test Cases

**AC-14** — Unit (6-row table-driven)
- Given: `IClock` mock with controlled `unix_time` + `ticks_msec`
- When: each of 6 scenarios executed
- Then: return value matches table; cache snapshot identical before/after call
- Edge cases: `ttl_seconds = 0` → anything > 0s expired; `anchor_unix = 0` (uninitialized clock) + no mono → `push_warning` + return false

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence-layer/test_is_expired_formula.gd` — 6 parameterised cases, all must pass

**Status**: [x] Created — `test_is_expired_formula.gd` (8 tests: 6 matrix rows + 2 edge cases)

---

## Dependencies

- Depends on: Story 001 (interface existence)
- Unlocks: Story 008 (migration uses `Time.get_ticks_msec()` for budget — same clock interface), Story 011 (touch uses is_expired for ITP)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-14 ✅ AC-14b ✅ AC-14c ✅)
**Deviations**: IClock injection not implemented — tests use computed anchor offsets from live Time.get_unix_time_from_system(). AC-14c zero-elapsed test has minor race potential (documented inline).
**Test Evidence**: Logic — `test_is_expired_formula.gd` (8 tests)
**Code Review**: APPROVED (inline)
