# Story 007: Anomaly Rate-Limiter (Formula 4)

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006
**ADR Decision Summary**: ADR-0006 mandates deterministic, injectable time for all rate-limiting logic; no wall-clock reads inside rate-check functions.

**Engine**: Godot 4.6 | **Risk**: LOW
**Performance**: `rate_limit_check()` is called from `_on_ability_cast` handler (Story 008, hot path). Must be O(k) where k = entries in sliding window (≤ RATE_CAP_PER_REASON = 10). `walk_anomaly_rate_windows()` is called from `_physics_process` — O(r×k) where r = 6 reasons × k=10 max = 60 iterations worst-case per frame. Analytic budget: 60 iterations × ~0.001ms = 0.06ms per frame. Well within ADR-0001 0.5ms EnemyDirector orchestration budget.

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [x] AC-09a [Logic|BLOCKING|unit]: Given `_anomaly_rate_tracker` initialized. When 100 calls `rate_limit_check("GSM_SUSPENDED", 0)` (time-injected, all same ms). Then: first 10 return `true`; next 90 return `false`. `dropped_count` for that reason == 90 in the tracker. Then `walk_anomaly_rate_windows(1001)` → `combat_metric_anomaly` emitted exactly once with `{reason: &"GSM_SUSPENDED", dropped_count: 90, aggregate: true}`.
- [x] AC-09b [Logic|BLOCKING|unit]: Given 6 different reasons each receiving 100 calls at same `now_ms=0`. When `rate_limit_check(reason_i, 0)` × 100 for each of the 6 reasons. Then: each reason independently allows exactly 10 passes (total 60 passes across all reasons); each reason independently caps at 10. Reasons do NOT share a global cap.
- [x] AC-09c [Logic|BLOCKING|unit]: Window boundary — sliding eviction correctness. Given 10 calls at `now_ms=0` (cap reached). When 10 more calls at `now_ms=999` (still in window). Then: all 10 at 999ms are dropped (cap not released yet). When `walk_anomaly_rate_windows(1000)` — first batch at 0ms evicted. When 10 new calls at `now_ms=1000`. Then: up to 10 new calls pass (window rolled; old entries evicted).

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Public method: `rate_limit_check(reason: StringName, now_ms: int) -> bool`
- Sliding 1-second window per reason (not global). Window size = `RATE_WINDOW_MS = 1000`.
- Evict timestamps outside `[now_ms - RATE_WINDOW_MS, now_ms]` from sliding window.
- Cap at `RATE_CAP_PER_REASON = 10` emissions per window.
- `dropped_count` accumulated in `_anomaly_rate_tracker[reason].dropped` counter.
- On window eviction with `dropped_count > 0`: emit `combat_metric_anomaly` with `{reason, dropped_count, aggregate: true}` then reset counter.
- Inject `now_ms` as parameter — NO `Time.get_ticks_msec()` inside this function (injectable time for deterministic tests).
- `_anomaly_rate_tracker: Dictionary[StringName, RateWindow]` where `RateWindow` is inner class: `{ timestamps: Array[int], dropped: int }`.
- 6 valid anomaly reasons (StringName): `GSM_SUSPENDED`, `INVALID_ABILITY_ID`, `NEGATIVE_DAMAGE`, `CLAMP_TRIGGERED`, `DEAD_TARGET_RESOLVE`, `RNG_INJECTION_MISSING`.
- Call `walk_anomaly_rate_windows(now_ms: int)` from `_physics_process` to trigger eviction + aggregate emit.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 005: `combat_metric_anomaly` signal declaration
- Story 008: Consuming rate_limit_check for GSM_SUSPENDED reason
- Story 009: Consuming rate_limit_check for CLAMP_TRIGGERED (queue overflow)
- Story 015: Consuming rate_limit_check for PARTICLE_THROTTLE events (separate reason set)
- Story 018: Consuming rate_limit_check for CLAMP_TRIGGERED (AOE target clamp)
- Story 019: Consuming rate_limit_check for DEAD_TARGET_RESOLVE

---

## QA Test Cases

**AC-09**: Given: injected time sequence — 100 calls all at `now_ms=0`. When: `rate_limit_check("GSM_SUSPENDED", 0)` × 100. Then: first 10 return `true`, next 90 return `false`.

Then advance time: `walk_anomaly_rate_windows(1001)`. Then: `combat_metric_anomaly` emitted once with `{reason: "GSM_SUSPENDED", dropped_count: 90, aggregate: true}`.

Edge case — 6 different reasons simultaneously: each has independent cap (10 per reason × 6 reasons = 60 total allowed within 1 second).

Edge case — window boundary: 10 calls at `now_ms=0`, then 10 calls at `now_ms=999` (still in window), then `walk_anomaly_rate_windows(1000)` evicts first batch. New calls at 1000ms should allow up to 10 more.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_director/test_anomaly_rate_limiter.gd`
**Status**: [x] Created; GUT 43/43 PASS (Godot 4.6.2, 2026-05-31)

---

## Completion Notes

**Completed**: 2026-05-31
**Criteria**: 3/3 passing
**Implementation**: `rate_limit_check(reason, now_ms)` + `walk_anomaly_rate_windows(now_ms)` added to enemy_director.gd. `RateWindow extends RefCounted` inner class + RATE_WINDOW_MS=1000/RATE_CAP_PER_REASON=10 constants. Half-open eviction: `ts <= now_ms - RATE_WINDOW_MS`. Aggregate CombatAnomalyPayload emitted when window fully expired with drops > 0.
**Key design note**: QL-STORY-READY Note 1 addressed — half-open window boundary (`ts <= now_ms - RATE_WINDOW_MS`) confirmed correct; test_ac09c_walk_1000_evicts_ts0 locks this semantics.
**Test Evidence**: 9 tests covering AC-09a (4), AC-09b (2), AC-09c (3). GUT green.
**Code Review**: Skipped (self-implemented; QL-STORY-READY ADEQUATE).

---

## Dependencies

- Depends on: Story 001 (EnemyDirector class body + `_anomaly_rate_tracker` container), Story 005 (emit via `combat_metric_anomaly` signal)
- Unlocks: Story 008 (GSM gate uses rate-limiter), Story 009 (AOE mutex uses rate-limiter), Story 015 (particle throttle uses rate-limiter), Story 018 (AOE pipeline uses rate-limiter), Story 019 (dedupe uses rate-limiter)
