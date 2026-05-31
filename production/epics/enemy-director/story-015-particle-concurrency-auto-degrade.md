# Story 015: Particle Concurrency Cap + Auto-degrade (Rule 11 + Formula 3)

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 structural
**ADR Decision Summary**: ADR-0001 mandates particle concurrency caps for mobile web budget compliance; throttle/recovery hysteresis prevents thrashing; `MAX_CONCURRENT_PARTICLE_EMITTERS` must be a `const` (CI lint enforced).

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-23 [Logic|BLOCKING|unit]: Given `_frame_time_window` with 3 consecutive values all >33ms. When `_is_throttle_active()` called. Then: returns `true`; `_caller_mult` drops from `1.5→1.0`; emit `combat_metric_anomaly(reason="PARTICLE_THROTTLE_ENGAGED")` rate-limited. (EC-29)
- [ ] AC-24 [Logic|BLOCKING|unit]: Given throttle active + 60 consecutive frame_time values all <20ms in `_recovery_window`. When recovery check triggers. Then: `_caller_mult` restores to `1.5`; emit `combat_metric_anomaly(reason="PARTICLE_THROTTLE_RELEASED")` rate-limited. (EC-30) INV-4: hysteresis gap = 33.0 - 20.0 = 13.0ms > 5ms ✓.
- [ ] [Note: AC-25 (iPhone 12 real hardware benchmark) reclassified → Story 022 BLOCKED hardware]

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `_frame_time_window: Array[float]` — rolling FIFO of last 3 values (`FRAME_TIME_SAMPLE_SIZE = 3`). NOT EWMA — immediate emergency response.
- `_recovery_window: Array[float]` — rolling FIFO of last 60 values (`RECOVERY_SAMPLE_SIZE = 60`).
- `MAX_CONCURRENT_PARTICLE_EMITTERS = 8` — declared as `const` (not `var`; CI lint Story 004 AC-26 enforces).
- `FRAME_TIME_BUDGET_MS = 33.0` — throttle trigger threshold (>33ms = above 30fps floor).
- `FRAME_TIME_RECOVERY_MS = 20.0` — recovery threshold (<20ms = comfortably above 50fps).
- INV-4 static assertion: `FRAME_TIME_BUDGET_MS > FRAME_TIME_RECOVERY_MS + 5.0` → `33.0 > 25.0 ✓`.
- `_caller_mult: float` — multiplier passed to `ParticleSystemWrapper.play(preset, pos, caller_mult)`.
  - Normal: `1.5` (boss spectacle ambient)
  - Throttled: `1.0` (reduce particle emission rate)
- `_record_frame_time(ft: float)` — public injectable method; no `Time.get_ticks_msec()` inside throttle logic.
- Throttle engage logic: if all 3 values in `_frame_time_window > FRAME_TIME_BUDGET_MS` → engage throttle.
- Recovery logic: if all 60 values in `_recovery_window < FRAME_TIME_RECOVERY_MS` → release throttle.
- Anomaly reasons: `PARTICLE_THROTTLE_ENGAGED` / `PARTICLE_THROTTLE_RELEASED` — rate-limited via Story 007.
- Particle dispatch queue: `_particle_dispatch_queue: Array[ParticleDispatch]`. Dispatches queued during throttle are degraded (lower `caller_mult`) when dequeued.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004: `check_particle_concurrency_cap.gd` CI lint that enforces `const` keyword
- Story 007: Rate-limiter consumed here for anomaly emit
- Story 017: Boss entry cascade that uses `caller_mult=1.2` (boss spectacle override > normal ambient)
- Story 022: BLOCKED hardware benchmark for AC-25

---

## QA Test Cases

**AC-23 throttle engage**: Given: inject `[35.0, 36.0, 34.0]` into `_frame_time_window` via `_record_frame_time()` × 3. When: `_is_throttle_active()`. Then: returns `true`; `_caller_mult == 1.0`; `combat_metric_anomaly` spy called with `reason == "PARTICLE_THROTTLE_ENGAGED"`.

**AC-24 throttle release**: From throttle active state, inject 60 frame times all `18.0` via `_record_frame_time()` × 60. When: recovery check auto-triggers. Then: `_caller_mult == 1.5`; anomaly spy called with `reason == "PARTICLE_THROTTLE_RELEASED"`.

**INV-4 static**: Assert `FRAME_TIME_BUDGET_MS(33.0) - FRAME_TIME_RECOVERY_MS(20.0) = 13.0 > 5.0`. This can be a compile-time `assert` in the script.

**Hysteresis**: Given: throttle engaged. When: inject 59 frames at 18ms + 1 frame at 21ms. Then: throttle NOT released (recovery window not all below threshold). When: inject 60 more frames all at 18ms. Then: throttle released.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/enemy_director/test_throttle_engagement.gd`
- `tests/unit/enemy_director/test_throttle_recovery.gd`
**Status**: [x] Created; GUT 9/9 (story) + 205/205 (enemy+combat+static suite) PASS; concurrency lint PASS (Godot 4.6.3, 2026-06-01)

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3 passing (AC-23 engage EC-29, AC-24 release EC-30, INV-4 hysteresis; AC-25 → Story 022 BLOCKED hardware)
**Implementation**: throttle hysteresis on EnemyDirector — `_record_frame_time` (public injectable, no clock in throttle logic) → `_evaluate_throttle` (engage: 3 samples all >33ms; release: 60 samples all <20ms) → `_is_throttle_active`/`get_caller_mult` (1.5↔1.0); `_emit_throttle_anomaly` (PARTICLE_THROTTLE_ENGAGED/RELEASED, rate-limited, transition-only). Consts MAX_CONCURRENT_PARTICLE_EMITTERS=8 (const, lint-enforced), FRAME_TIME_SAMPLE_SIZE/RECOVERY_SAMPLE_SIZE/FRAME_TIME_BUDGET_MS/FRAME_TIME_RECOVERY_MS/CALLER_MULT_*. INV-4 fail-loud assert in _ready.
**Unblocks**: Story 004 particle-concurrency-cap lint (const enforced; flipped stale "cap absent" static test).
**Scope note**: `_record_frame_time` is NOT auto-wired into _physics_process (avoids cross-test pollution + frame-time source is a presentation concern) — the game frame-monitor feeds it; `_particle_dispatch_queue` deferred to Story 017 (boss cascade) — no AC requires it here.
**Test Evidence**: test_throttle_engagement.gd (5) + test_throttle_recovery.gd (4).
**Code Review**: deferred to batch review (autonomous epic completion run).

---

## Dependencies

- Depends on: Stories 001 (class body containers), 007 (rate-limiter for anomaly emit)
- Unlocks: Story 017 (boss cascade uses particle dispatch), Story 022 (hardware benchmark when unblocked)
