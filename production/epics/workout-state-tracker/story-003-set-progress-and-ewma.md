# Story 003: set_progress Derivation + Monotonicity + EWMA

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirements**: `TR-wst-004`, `TR-wst-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: State Machine Contract
**ADR Decision Summary**: Drift-tolerant TTL `is_expired` per Contract 9; atomic transition with generational lock for `workout_completed`; Contract 9 monotonic-clock semantics apply to EWMA persistence timestamps.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure GDScript arithmetic — no post-cutoff API risk. `Time.get_unix_time_from_system()` stable since Godot 4.0.

**Control Manifest Rules (Core layer)**:
- Required: `set_progress` MUST be non-decreasing within a single workout (CF-1 invariant)
- Required: Formula 2 EWMA computed AFTER `WorkoutSummaryRO` sealed, BEFORE workout state reset (CF-3 ordering)
- Forbidden: Time-based extrapolation or interpolation of `set_progress` (Rule 16 NEVER #4)
- Forbidden: `set_progress` below 0.0 or above 1.0 (hard clamp both ends)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-04** (Rule 4 + CF-1): GIVEN `phase == SET_ACTIVE` + `set_progress == 0.42`, WHEN estimator recomputes backward to `0.31`, THEN WST suppresses downward revision; forwarded value stays `0.42`; `set_progress_changed` NOT emitted; log `WST_PROGRESS_MONOTONIC_BLOCKED` (INFO).
- [ ] **AC-12** (Rule 4 + CI-2): GIVEN GymSys provides no `planned_total_sets` but `historical_avg_sets > 0`, WHEN read `get_workout_snapshot().set_progress_is_estimated`, THEN returns `true`; when future signal extension exposes `planned_total_sets`, returns `false`.
- [ ] **AC-19** (Formula 2 EWMA + CF-3): GIVEN prior `historical_avg_sets = 6.0`, alpha=0.3, new workout 4 sets completed, WHEN `workout_completed` triggers finalise, THEN **relative call order**: `build_summary ≺ emit_summary_available ≺ compute_ewma ≺ persist_snapshot ≺ transition_to_idle` (CF-3 binding — lock RELATIVE ordering, not absolute step list); EWMA written to `wst.history.avg_sets == 5.4 ± 0.001`.
- [ ] **AC-20** (Formula 1 + Knob `SET_PROGRESS_BONUS_SET_CLAMP=0.95`): GIVEN Example A full-data path (planned 6 sets × 10 reps, set 5, reps 8/10), WHEN compute, THEN `set_progress == 0.800 ± 0.001`; Example B estimated path (historical_avg_sets=5.2, reps_per_set=9.4→round 9, set 5, reps 8) → `set_progress == 0.815 ± 0.005`; bonus set (current > planned) → clamp ≤ 0.95.
- [ ] **AC-22** (CF-1 fuzz): GIVEN 100 seeded random `set_progress` raw events (fixed seed constant), WHEN apply Formula 1 monotonic clamp, THEN forwarded sequence strictly non-decreasing across all 100; any downward step → assert fail.
- [ ] **AC-23** (CF-3 pre-reset guard): GIVEN spy on workout state reset, WHEN Formula 2 EWMA computed, THEN assert `_current_workout_id != null` at compute time (reset not yet run); reset_after_ewma ordering invariant enforced.

---

## Implementation Notes

*Derived from ADR-0006 + GDD Formula 1/2 specs:*

- **Estimated path (current default)**: `set_progress_raw = clamp((current_set_index - 1 + reps_completed_in_set / effective_planned_reps) / effective_planned_total, 0.0, 1.0)` where `effective_planned_total = max(current_set_index + 1, historical_avg_sets)` and `effective_planned_reps = max(1, round(historical_avg_reps_per_set))`.
- **Bonus-set cap**: Apply `set_progress_raw = min(set_progress_raw, SET_PROGRESS_BONUS_SET_CLAMP)` (default 0.95) BEFORE monotonic clamp when `current_set_index > effective_planned_total`.
- **Monotonic clamp**: `set_progress = max(set_progress_raw, previous_set_progress)` — ALWAYS applied, both paths.
- **`set_progress_is_estimated`**: `true` when `planned_total_sets` is unknown (estimated path active). Exposed via `WorkoutSnapshotRO`.
- **EWMA Formula 2**: `new_avg = alpha × sets_completed + (1 - alpha) × old_avg`. First workout (old_avg == null) → `new_avg = sets_completed` (skip blend, cold-start rule).
- **CF-3 execution order**: EWMA must run AFTER `WorkoutSummaryRO` is sealed (so `current_set_index` is correct) and BEFORE workout state reset (so `_current_workout_id` is non-null). Use call-order spy in tests to assert relative ordering.
- **EC-15 cold-start**: If both `planned_total_sets` and `historical_avg_sets` are null/0 → lock `set_progress = SET_PROGRESS_NEUTRAL_FALLBACK` (0.5).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: WorkoutPhase FSM (prerequisite)
- [Story 006]: `WorkoutSummaryRO.final_set_progress` binding (CF-2) + `workout_completed` forwarding
- [Story 008]: Persistence of `wst.current_workout.set_progress_state` + `wst.history.avg_sets` to PersistenceLayer

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-04 — monotonic downward suppression (CF-1)
```
Given: phase == SET_ACTIVE, set_progress == 0.42 (forwarded)
When:  estimator recomputes raw == 0.31
Then:  forwarded set_progress stays 0.42 (max(prev, raw) clamp)
       AND set_progress_changed NOT emitted
       AND log WST_PROGRESS_MONOTONIC_BLOCKED at INFO
Edge:  recompute raw == 0.42 (equal) → still no emit (non-decreasing, no change)
```

### AC-12 — set_progress_is_estimated flag
```
Given: GymSys provides no planned_total_sets but historical_avg_sets > 0
When:  read get_workout_snapshot().set_progress_is_estimated
Then:  == true
When:  planned_total_sets exposed via signal extension (inject full-data mock)
Then:  == false
Edge:  historical_avg_sets cold (null) AND no planned → still estimated==true (EC-15 neutral fallback)
```

### AC-19 — EWMA compute order + value (Formula 2, CF-3)
```
Given: historical_avg_sets == 6.0, alpha == 0.3, workout with 4 sets completed
When:  workout_completed triggers finalise; use call-order spy
Then:  relative order: build_summary ≺ emit_summary_available ≺ compute_ewma ≺ persist ≺ transition_to_idle
       (CF-3 binding: summary sealed BEFORE compute_ewma; reset AFTER compute_ewma)
       AND wst.history.avg_sets == 5.4 ± 0.001  (0.3×4 + 0.7×6.0)
Edge:  first workout (old_avg == null) → new_avg == sets_in_completed_workout (no EWMA blend)
Note:  lock CF-3 RELATIVE ordering; do not hard-assert absolute 6-step list index positions
```

### AC-20 — Formula 1 both paths + bonus clamp
```
Given: Example A full-data path (planned 6 sets × 10 reps, set 5, reps 8/10)
When:  compute set_progress
Then:  == 0.800 ± 0.001

Given: Example B estimated path (historical_avg_sets=5.2, reps_per_set=9.4→round→9, set 5, reps 8)
       effective_planned_total = max(5+1, 5.2) = 6
When:  compute
Then:  == 0.815 ± 0.005  ((4 + 8/9) / 6 = 0.8148)

Given: bonus set (current_set_index > planned_total_sets)
When:  compute
Then:  set_progress ≤ SET_PROGRESS_BONUS_SET_CLAMP (0.95)

Edge:  planned_reps == 0 → falls to estimated path (EC-15); log WST_PLANNED_ZERO_001
Edge:  both historical and planned cold → lock 0.5 (SET_PROGRESS_NEUTRAL_FALLBACK, EC-15)
```

### AC-22 — monotonic fuzz (CF-1)
```
Given: 100 seeded random set_progress raw events (FIXED SEED = 42, stored as fixture constant)
When:  apply Formula 1 monotonic clamp to each
Then:  forwarded sequence strictly non-decreasing across all 100
       any forwarded[i] < forwarded[i-1] → assert fail with offending index
Note:  seed is a FIXTURE CONSTANT — not runtime random (testing-standards determinism)
```

### AC-23 — EWMA reads pre-reset workout_id (CF-3)
```
Given: spy on workout state reset call; spy on EWMA compute call
When:  Formula 2 EWMA computed inside workout_completed handler
Then:  assert _current_workout_id != null AT compute time (before reset runs)
       assert EWMA compute ≺ reset in spy call sequence
Edge:  assert reset runs AFTER ewma write — spy records sequence positions
```

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/workout_state_tracker/test_set_progress_and_ewma.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/core/workout_state_tracker/test_set_progress_and_ewma.gd`

---

## Dependencies

- Depends on: Story 001 (WorkoutPhase FSM) must be DONE
- Unlocks: Story 006 (CF-2 final_set_progress at workout_completed), Story 008 (EWMA persistence)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 6/6 passing
**Deviations**: None — all code review suggestions (W1 EC-15 fix, W2 FUZZ_SEED, 4 boundary tests) applied before close
**Test Evidence**: Logic — `tests/unit/core/workout_state_tracker/test_set_progress_and_ewma.gd` (18 tests: 14 AC + 4 boundary)
**Code Review**: Complete (APPROVED WITH SUGGESTIONS — all suggestions applied)
