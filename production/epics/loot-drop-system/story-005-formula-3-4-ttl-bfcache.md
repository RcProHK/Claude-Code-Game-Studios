# Story 005: Formula 3 (Pending TTL Expiry) + Formula 4 (bfcache Resume Action)

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-014`, `TR-loot-015`
*(TR-loot-014: "Pending TTL expiry — 30-day soft + 37-day hard cap"; TR-loot-015: "bfcache resume action — 30s threshold")*

**ADR Governing Implementation**: ADR-0003 (Save State Strategy, Accepted 2026-05-30) primary; ADR-0006 (State Machine Contract, Accepted) secondary
**ADR Decision Summary**: `lootdrop_pending_ttl_days = 30` (SOFT) / `lootdrop_pending_hard_cap_days = 37` (HARD). `DRIFT_TOLERANCE_S = 300` (ADR-0003 wall-clock drift budget — CI-3). Drift tolerance only applies at SOFT boundary (prevents clock-fast false-expiry). HARD boundary uses raw age (prevents clock-slow infinite delay). bfcache resume: 30s threshold — mid-reveal continue vs defer-to-next-boot.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_unix_time_from_system()` stable. `Time.get_ticks_msec()` for ms-level bfcache delta. No post-cutoff API sensitivity.

**Control Manifest Rules (Core layer)**:
- Required: `pending_since_server` (backend timestamp) is authoritative for hard-cap loot eviction — client timestamp is mirror only (ADR-0006 Contract 15)
- Required: `DRIFT_TOLERANCE_S = 300` MUST match ADR-0003 wall-clock drift budget (CI-3, INV from GDD)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-10** — 30d+4m age, clock-fast +5m → FRESH (`adjusted_age=2,591,940 < SOFT_TTL=2,592,000`) ✅
- [x] **AC-11** — 38d age, slow clock → HARD_EXPIRED (raw age at HARD boundary, clock skew ignored) ✅
- [x] `pending_ttl_expired()` returns SOFT_EXPIRED at day 31 ✅
- [x] `pending_ttl_expired()` returns FRESH for brand new drop (age=0) ✅
- [x] **AC-12** — MID_REVEAL delta=12,000ms → CONTINUE_ANIMATION; delta=30,000ms (boundary ≤) → CONTINUE ✅
- [x] **AC-13** — MID_REVEAL delta=45,000ms → DEFER_TO_NEXT_BOOT; delta=30,001ms → DEFER ✅
- [x] PRE_REVEAL any delta → NO_ACTION ✅
- [x] POST_REVEAL_PRE_HANDOFF any delta → CONTINUE_ANIMATION ✅

---

## Implementation Notes

*Derived from GDD Formula 3 + Formula 4:*

**Formula 3** — `pending_ttl_expired(drop_record, now_unix)`:
```gdscript
static func pending_ttl_expired(created_at_unix: int, now_unix: int) -> int:  # ExpiryState
    const SOFT_TTL_DAYS: int = 30
    const HARD_CAP_DAYS: int = 37
    const DRIFT_TOLERANCE_S: int = 300

    var age_s: int = now_unix - created_at_unix
    var adjusted_age_s: int = age_s - DRIFT_TOLERANCE_S  # only for SOFT boundary

    if adjusted_age_s < SOFT_TTL_DAYS * 86400:
        return ExpiryState.FRESH
    elif age_s < HARD_CAP_DAYS * 86400:
        return ExpiryState.SOFT_EXPIRED
    else:
        return ExpiryState.HARD_EXPIRED
```

**Formula 4** — `bfcache_resume_action(drop_state, suspended_at_ms, resumed_at_ms)`:
```gdscript
static func bfcache_resume_action(drop_state: int, suspended_at_ms: int, resumed_at_ms: int) -> int:  # ResumeAction
    const BFCACHE_CONTINUE_THRESHOLD_MS: int = 30000

    match drop_state:
        DropRevealState.POST_REVEAL_PRE_HANDOFF:
            return ResumeAction.CONTINUE_ANIMATION
        DropRevealState.PRE_REVEAL:
            return ResumeAction.NO_ACTION
        DropRevealState.MID_REVEAL:
            var delta_ms: int = resumed_at_ms - suspended_at_ms
            if delta_ms <= BFCACHE_CONTINUE_THRESHOLD_MS:
                return ResumeAction.CONTINUE_ANIMATION
            else:
                return ResumeAction.DEFER_TO_NEXT_BOOT
    return ResumeAction.NO_ACTION  # fallback
```

**Note on ADR-0006 Contract 15**: `created_at_unix` should preferably come from backend `pending_since_server` (authoritative for hard-cap decisions). The formula accepts either; callers must pass backend timestamp for hard-cap decisions. For tests, use arbitrary unix timestamps.

**CF-3**: Formula 3 (process-level TTL, days) and Formula 4 (session-level bfcache, ms) are non-overlapping concerns — they measure different things and must not be conflated.

---

## Out of Scope

- Story 009: Autoload calls `pending_ttl_expired()` on boot TTL check (step 6 of boot sequence)
- Story 012: Full persistence lifecycle that triggers these checks
- Story 015: bfcache full flow end-to-end (BLOCKED)

---

## QA Test Cases

**AC-10 (drift tolerance at SOFT boundary)**:
- Given: `created_at_unix = now - 2_592_240` (30 days + 4 min), effective clock-fast +300s
- When: `pending_ttl_expired(created_at, now)` called
- Then: `adjusted_age = 2_591_940 < 2_592_000 (SOFT_TTL)` → FRESH
- Edge cases: `created_at = now - 2_592_000` exactly (at SOFT boundary, no drift) → adjusted = 2_591_700 < 2_592_000 → FRESH

**AC-11 (HARD boundary raw age)**:
- Given: `created_at_unix = now - 3_283_200` (38 days), clock skew = -600s (slow)
- When: `pending_ttl_expired(created_at, now)` called
- Then: `raw_age = 3_283_200 > HARD_CAP = 3_196_800` → HARD_EXPIRED (clock skew ignored at HARD boundary)
- Edge cases: `age = 37×86400 = 3_196_800` exactly → HARD_EXPIRED (boundary inclusive)

**AC-12 (bfcache continue)**:
- Given: `drop_state = MID_REVEAL, suspended_at_ms = 1000, resumed_at_ms = 13000` (delta=12,000 ≤ 30,000)
- When: `bfcache_resume_action()` called
- Then: CONTINUE_ANIMATION
- Edge cases: `delta = 30,000` (exactly threshold) → CONTINUE_ANIMATION (≤)

**AC-13 (bfcache defer)**:
- Given: `drop_state = MID_REVEAL, delta_ms = 45,000`
- When: `bfcache_resume_action()` called
- Then: DEFER_TO_NEXT_BOOT
- Edge cases: `delta = 30,001` → DEFER_TO_NEXT_BOOT; PRE_REVEAL with any delta → NO_ACTION

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 
- `tests/unit/loot/test_pending_ttl_drift_tolerance.gd` (AC-10)
- `tests/unit/loot/test_pending_ttl_hard_cap.gd` (AC-11)
- `tests/unit/loot/test_bfcache_resume_continue.gd` (AC-12)
- `tests/unit/loot/test_bfcache_resume_defer.gd` (AC-13)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (ExpiryState, ResumeAction enums)
- Unlocks: Story 009 (autoload boot uses TTL check), Story 012 (persistence lifecycle calls TTL), Story 015 (bfcache full flow — BLOCKED)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 8/8 passing
**Deviations**:
- ADVISORY — `src/core/loot_enums.gd` modified to add `DropRevealState` enum (Story 002 AC list omitted this enum; Formula 4 requires it). Necessary scope extension, not unrelated scope creep. Logged in tech-debt-register.md.
**Test Evidence**: Logic — 4 unit test files (27 test functions):
- `tests/unit/loot/test_pending_ttl_drift_tolerance.gd` (8 tests, AC-10)
- `tests/unit/loot/test_pending_ttl_hard_cap.gd` (6 tests, AC-11)
- `tests/unit/loot/test_bfcache_resume_continue.gd` (6 tests, AC-12)
- `tests/unit/loot/test_bfcache_resume_defer.gd` (7 tests, AC-13)
**Code Review**: Complete (passed)
