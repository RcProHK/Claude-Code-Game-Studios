# Story 023: BLOCKED — Boss Anchor Latency Gate

> **Epic**: Enemy Director
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3h (when unblocked)
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Accepted data-contract)
**ADR Decision Summary**: ADR-0002 Accepted data-contract locks the `workout_completed` event schema; the boss anchor latency gate (p95 ≤ 500ms) validates the full GymSys integration path from workout completion to boss visible on-screen. Requires #9 WorkoutStateTracker implementation to expose `set_progress`.

**Engine**: Godot 4.6 | **Risk**: HIGH

---

## Blockers

- **BLOCKED**: Requires `#9 WorkoutStateTracker` GDD + implementation — specifically `set_progress` field exposure from WST. Story 016 boss anchor pre-spawn depends on this value. Promote to BLOCKING once WST is complete.
- **BLOCKED**: Requires end-to-end integration with live GymSys backend for realistic `workout_completed` event timing. Mock backend cannot reproduce real network latency distribution.

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-20 [Logic|ADVISORY|integration]: Given: 100 simulated workout sessions. When: `workout_completed` event arrives from GymSys. Then: p95 delta (`workout_completed` timestamp → boss visible-on-screen frame) ≤ 500ms. (Falsifiable Test #2 binding, FR-2)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Run AFTER Stories 016 + 017 (full boss anchor pipeline implemented) AND #9 WorkoutStateTracker epic complete.
- Test harness: simulate 100 workout completion events with known timestamps. Record: `t_event` (workout_completed received) and `t_visible` (frame where `boss.visible == true`). Compute: delta array; calculate p95.
- p95 calculation: sort 100 deltas; index 95 = p95 value. Pass if `deltas[95] ≤ 500ms`.
- Measurement points:
  - `t_event`: timestamp logged in `_on_state_changed` handler when `to == "BossEncounter"` first received
  - `t_visible`: timestamp logged in boss cascade step 1 (`boss.visible = true`)
- If p95 > 500ms: profile `_on_state_changed` handler; check for unintended `await` or `call_deferred` in cascade; check Physics frame rate.
- After unblocking: reclassify from ADVISORY to BLOCKING if ADR-0002 requires it.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 016: Boss pre-spawn implementation (pre-condition for this latency test)
- Story 017: Boss entry cascade (the measured endpoint)
- Epic #9: WorkoutStateTracker (prerequisite, separate epic)

---

## QA Test Cases

*Partially automatable once WST is available; requires mock GymSys event source for full simulation.*

**AC-20**: Given: mock GymSys client emitting `workout_completed` with recorded timestamp. When: 100 events processed in integration test. Then: compute deltas; sort; `deltas[94] ≤ 500ms` (0-indexed p95). Evidence: raw delta array in test output.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/enemy_director/test_boss_anchor_latency.gd` (deferred — not yet created)
**Status**: [ ] Not yet created (blocked)

---

## Dependencies

- Depends on: Stories 016, 017 (full boss anchor pipeline), `#9 WorkoutStateTracker` implementation complete
- Unlocks: ADR-0002 transport/CORS empirical validation milestone
