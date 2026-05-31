# Story 008: Persistence Snapshot wst.* + Bfcache Resume

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirement**: `TR-wst-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: State Machine Contract
**ADR Decision Summary**: Contract 9 — drift-tolerant TTL `is_expired()` with `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300`; strict greater-than `elapsed > 86400s` (boundary = valid). Contract 3 — `SerializableResource` for persisted payload envelopes.

**Secondary reference**: ADR-0003 (Proposed — Save State Strategy). wst.* namespace authority defined in GDD Rule 7. ADR-0003 acceptance may refine namespace conventions; update snapshot keys if ADR-0003 revises wst.* spec.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `FileAccess.store_*` returns bool (4.4+ breaking change). Real mobile-Safari bfcache behavior is browser-dependent — controlled `_ready()` re-run tests replace on-device for CI. `IndexedDB` write ack semantics on Web Export require VS spike (ADR-0006 Verification Required #2).

**Control Manifest Rules (Core layer + Foundation layer)**:
- Required: `is_expired()` uses strict greater-than (`elapsed > TTL_seconds`); boundary (exactly 24h) is valid (EC-26)
- Required: `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300` drift tolerance in `is_expired()` (ADR-0006 Contract 9)
- Required: Schema migration chain bounded at `MAX_CHAIN_LENGTH = 6` × `MIGRATION_BUDGET_MS = 150ms` (ADR-0006 Contract 10)
- Required: On write fail → emit `wst.persist_failed(key, reason)`, continue in-memory operation (NOT retry inline) (EC-24)
- Forbidden: `localStorage` — use `user://` (FileAccess / PersistenceLayer) instead (ADR-0003 + technical-preferences.md)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-16** (Rule 7 + Rule 12 + Falsifiable Test #5 — *controlled CI portion*): GIVEN PersistenceLayer mock pre-seeded with `wst.*` snapshot (phase=SET_ACTIVE, set_history N=5, `started_at` within TTL), WHEN WST autoload `_ready()` re-runs (simulated resume), THEN snapshot restored; phase / set_history / set_progress reconstructed; `_cached_dominant_class` recomputed from set_history per Rule 5 replay; substate → READY; emits `bfcache_resumed(was_mid_workout=true, restored_phase=SET_ACTIVE)`. *(Real Safari bfcache pagehide→30s→pageshow timing = DEFERRED to on-device manual — Falsifiable Test #5.)*
- [ ] **AC-32** (EC-36 + Falsifiable Test #5 — *controlled CI portion*): GIVEN injected clock; snapshot `started_at`. WHEN `_ready()` re-runs with elapsed < 24h → resume succeeds, phase consistent. WHEN `_ready()` re-runs with elapsed > 24h → snapshot discarded; phase reset IDLE; emit `workout_state_discarded(reason="ttl_expired")`; NO half-state corruption. Boundary exactly 24h → treated valid (strict `>`). *(Real 30-min bfcache + #2 reconnect = DEFERRED.)*
- [ ] **AC-35** (EC-17/23 + Knob `SNAPSHOT_BYTE_TRUNCATION_THRESHOLD=256KB` + INV-7): GIVEN oversized `set_history` causing serialized snapshot > 256KB, WHEN persist, THEN truncate to last `SNAPSHOT_TRUNCATION_MAX_SETS` (50) sets + log `WST_SNAPSHOT_TRUNC_001` (WARN, payload=original_count+kept_count); aggregate stats (total_volume, completed_exercises_count) already derived — not lost; resume from truncated snapshot reconstructs partial state without crash.
- [ ] **AC-36** (EC-24): GIVEN PersistenceLayer mock returns `false` on `write("wst.current_workout.phase", ...)`, WHEN WST encounters write fail, THEN NOT retry inline; emit `wst.persist_failed(key, reason)`; in-memory state continues normally; subsequent `set_logged` events still processed.

---

## Implementation Notes

*Derived from ADR-0006 Contract 9 + GDD Rule 7/12:*

- **Persisted keys** (Rule 7):
  | Key | Type | Written on |
  |---|---|---|
  | `wst.current_workout.phase` | int (enum) | `phase_changed` (flush=true) |
  | `wst.current_workout.id` | String | `workout_started` |
  | `wst.current_workout.started_at` | int (unix ms) | `workout_started` |
  | `wst.current_workout.set_history` | Array[Dictionary] | `set_logged` |
  | `wst.current_workout.set_progress_state` | Dictionary | debounced 500ms |
  | `wst.current_workout.last_signal_received_at` | int (unix ms) | each signal |
  | `wst.history.avg_sets` | float | `workout_completed` |
  | `wst.history.last_completed_class` | int (enum) | `workout_completed` |
- **NOT persisted** (re-derived on resume): `_cached_dominant_class`, `set_progress`, substate, signal connections.
- **Resume sequence** (Rule 12 — `_ready()` body):
  1. Substate = INITIALISING
  2. Read `wst.current_workout.*` from PersistenceLayer
  3. `is_expired(started_at, WORKOUT_SNAPSHOT_TTL_HOURS × 3600)` — if expired: discard + emit `workout_state_discarded` + reset IDLE
  4. Reconstruct phase + set_history + estimator state
  5. Recompute `_cached_dominant_class` from set_history (Rule 5 replay)
  6. Recompute `_cached_set_progress` from estimator state (Rule 4)
  7. Subscribe signals via `connect_for_initial_state`
  8. Subscribe #1 GSM `state_changed`
  9. Substate → READY
  10. Emit `bfcache_resumed(was_mid_workout, restored_phase)`
- **`is_expired()` exact semantics** — `elapsed_s = wall_now - started_at_s`. If `|wall_diff - mono_diff| > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS (300)`: use monotonic. Return `elapsed_s > TTL_hours × 3600` (strict `>`, not `>=`).
- **Snapshot truncation** — if `serialized_bytes(set_history) > SNAPSHOT_BYTE_TRUNCATION_THRESHOLD (262144)`: keep last `SNAPSHOT_TRUNCATION_MAX_SETS (50)` entries. Aggregate stats frozen before truncation (Rule 10 seals them at workout_completed).
- **Write debounce** — `set_progress_state` writes debounced 500ms (Knob `SNAPSHOT_DEBOUNCE_MS`). If `workout_completed` arrives during debounce → force-flush write (bypass timer).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Substate INITIALISING → READY lifecycle (prerequisite)
- [Story 003]: set_progress formula re-derivation from estimator state
- [Story 004]: `_cached_dominant_class` re-derivation from set_history
- [Story 006]: `workout_completed_forwarded` + `WorkoutSummaryRO` sealing

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-16 — bfcache resume reconstruction [controlled CI portion]
```
Given: PersistenceLayer mock pre-seeded:
       wst.current_workout.phase = SET_ACTIVE
       wst.current_workout.set_history = [5 entries]
       wst.current_workout.started_at = now - 3600s (within 24h TTL)
When:  WST autoload _ready() re-runs (inject mock, call _ready())
Then:  phase restored == SET_ACTIVE
       set_history reconstructed (5 entries, deep_equal to pre-seeded)
       set_progress re-derived from estimator state
       _cached_dominant_class recomputed via Rule 5 set_history replay
       substate → READY
       bfcache_resumed(was_mid_workout=true, restored_phase=SET_ACTIVE) emitted
Edge:  NOT-persisted fields re-derived, not read from snapshot
Deferred: real mobile-Safari pagehide→30s→pageshow = on-device manual (Falsifiable Test #5) — DEFERRED
```

### AC-32 — TTL expiry on resume [controlled CI portion]
```
Given: snapshot started_at; inject clock via seam
When:  _ready() re-runs with injected elapsed < 24h
Then:  resume succeeds; phase consistent with snapshot
When:  _ready() re-runs with injected elapsed > 24h  (strict greater-than)
Then:  snapshot discarded; phase reset IDLE
       emit workout_state_discarded(reason="ttl_expired")
       NO half-state corruption (all workout-scoped fields cleared atomically)
Edge:  elapsed exactly == 24h (86400s) → treated valid (strict > means NOT expired at boundary)
Deferred: real 30-min bfcache + #2 reconnect on-device = DEFERRED to manual
```

### AC-35 — snapshot truncation (EC-23, INV-7)
```
Given: set_history large enough that serialized bytes > SNAPSHOT_BYTE_TRUNCATION_THRESHOLD (262144)
When:  persist triggered
Then:  truncate to last SNAPSHOT_TRUNCATION_MAX_SETS (50) sets
       log WST_SNAPSHOT_TRUNC_001 at WARN with payload original_count + kept_count
       aggregate stats (total_volume, completed_exercises_count) preserved (already derived pre-seal)
       resume from truncated snapshot reconstructs partial state without crash
Edge:  INV-7 — threshold (256KB) <= #3 MAX_STATE_FILE_BYTES (1MB)
Edge:  set_history exactly 50 entries → no truncation triggered
```

### AC-36 — persist write failure (EC-24)
```
Given: PersistenceLayer mock returns false on write("wst.current_workout.phase", ...)
When:  WST phase_changed triggers persist write
Then:  NOT retry inline
       emit wst.persist_failed(key="wst.current_workout.phase", reason)
       in-memory state continues (subsequent set_logged still processed and returns valid query values)
Edge:  assert query API returns live values after persist failure (in-memory continuity)
Edge:  failure on one key does not cascade to other keys
```

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/core/workout_state_tracker/test_snapshot_persist_resume.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/core/workout_state_tracker/test_snapshot_persist_resume.gd`

---

## Dependencies

- Depends on: Story 001 (phase machine), Story 002 (substate INITIALISING→READY), Story 003 (set_progress), Story 004 (dominant_class) must be DONE
- Unlocks: Story 012 (anti-fabrication chain test exercises full bfcache recovery path)

---

## Completion Notes
**Completed**: 2026-05-31
**Criteria**: 4/4 passing
**Deviations**:
- ADVISORY: `wst.current_workout.*` keys not explicitly deleted on workout completion; IDLE phase persist (started_at=0) provides incidental TTL expiry on next boot — not an explicit cleanup. Story 012 may want explicit delete.
- ADVISORY: W2 flush strategy — `_change_phase()` uses `flush=false` (PL timer-based) instead of spec's "flush=true for critical phase state". Accepted to avoid N IDB sync cycles during EC-06 force-flush chain.
**Test Evidence**: Integration — `tests/integration/core/workout_state_tracker/test_snapshot_persist_resume.gd` (11 tests)
**Code Review**: Complete (APPROVED — 1 CRITICAL + 3 WARNING + 3 GAP fixes applied)
