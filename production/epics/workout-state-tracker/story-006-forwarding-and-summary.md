# Story 006: workout_completed Forwarding + WorkoutSummaryRO + transition_id

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirements**: `TR-wst-013`, `TR-wst-019` (secondary)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation (primary)**: ADR-0006: State Machine Contract
**ADR Decision Summary**: Contract 2 — `transition_id` acquired from `GameStateMachine.acquire_transition_id()` (generational lock); never self-generate. Forward-recovery must reuse tombstone's `transition_id` verbatim. Contract 3 — `WorkoutSummaryRO` extends `SerializableResource`.

**Secondary ADR**: ADR-0009: Signal Payload Schema Convention — payloads minimal + intrinsic (event data + `transition_id`). Cross-cutting context (`workout_id`) late-bound at handler.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: ADR-0006 Contract 2 tombstone semantics partially unresolved (Q-A1) — AC-37 is ADR-RATIFICATION-GATED. `call_deferred(_transition_to_idle)` for auto-IDLE transition per Rule 2.

**Control Manifest Rules (Core layer)**:
- Required: `transition_id` MUST come from `GameStateMachine.acquire_transition_id()` — NEVER self-generate (ADR-0006 Contract 2 + Rule 16 NEVER #7)
- Required: Emission order: `phase_changed` ≺ `workout_summary_available` ≺ `workout_completed_forwarded` (Rule 10 strict order)
- Required: `workout_summary_available` emitted IMMEDIATELY BEFORE `workout_completed_forwarded` (Rule 16 NEVER #12)
- Required: Signal payloads minimal + intrinsic — `transition_id` is intrinsic to `workout_completed` (ADR-0009 §1)
- Forbidden: `total_volume` retroactively mutated after `WorkoutSummaryRO` sealed (CF-5 + Rule 16 NEVER #5)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-07** (Rule 1 + Rule 10): GIVEN #2 mock emits each signal through a full workout, WHEN observe WST outbound emissions, THEN exactly 6 forwarded signals: `workout_started_forwarded`, `workout_completed_forwarded(completed_at, transition_id)`, `workout_summary_available(summary)`, `set_progress_changed(new)` (debounced 500ms), `dominant_class_changed(new)` (on flip only), `phase_changed(from, to)`; `poll_failed`/`poll_recovered` NOT forwarded (internally consumed).
- [ ] **AC-15** (Rule 10 + CF-5): GIVEN `total_volume = 5000` in-progress, WHEN `workout_completed` → `WorkoutSummaryRO` sealed → late `set_logged(.., 5, 60.0)` arrives, THEN `WorkoutSummaryRO.total_volume == 5000` (frozen); late event dropped per EC-32.
- [ ] **AC-21** (Formula 4 + CF-2): GIVEN last `set_progress = 0.87` + set_history total = (5×100kg×5reps + 3×120kg×5reps), WHEN receive `workout_completed`, THEN `WorkoutSummaryRO.final_set_progress == 0.87` AND `WorkoutSummaryRO.total_volume == 4300.0`; late events don't overwrite.
- [ ] **AC-24** (CF-4 append-only fuzz): GIVEN 50 `set_logged` events, WHEN all processed, THEN `set_history[0..N-1]` at any intermediate snapshot is prefix-consistent (prior entries unchanged).
- [ ] **AC-25** (CF-5 stress): GIVEN `workout_completed` then 20 late `set_logged` within 1s, WHEN read `WorkoutSummaryRO`, THEN `total_volume` unchanged; 20 late events dropped; `WST_LATE_SET_001` logged 20 times at WARN.
- [ ] **AC-37** *(ADR-RATIFICATION-GATED — implement best-effort, do not block Done gate)* (EC-30): GIVEN mock GSM `acquire_transition_id()` returns same ID twice, WHEN second signal uses same ID, THEN WST drops via tombstone detection; log `WST_TXN_COLLIDE_001` (ERROR); no state corruption. Mark test `pending()` until ADR-0006 Contract 2 tombstone finalization.

---

## Implementation Notes

*Derived from ADR-0006 Contracts 2/3 + ADR-0009 + GDD Rule 10:*

- **Strict emission order** (Rule 10) — must execute in this sequence on `workout_completed`:
  1. Phase transition to `WORKOUT_COMPLETE`
  2. Emit `phase_changed(prev, WORKOUT_COMPLETE)`
  3. Build `WorkoutSummaryRO` (seal now — after this, no mutation)
  4. Emit `workout_summary_available(summary)` ← consumers cache snapshot
  5. Emit `workout_completed_forwarded(completed_at, transition_id)` ← consumers trigger actions
  6. (After: EWMA update, persist snapshot, auto-IDLE via `call_deferred`)
- **`WorkoutSummaryRO` fields** — `completed_at: int`, `transition_id: int`, `dominant_class: AbilityClass`, `completed_exercises_count: int`, `final_set_progress: float`, `total_sets_logged: int`, `total_volume: float`.
- **`transition_id` acquisition** — call `GameStateMachine.acquire_transition_id()` at `WORKOUT_COMPLETE` phase entry. Store once, use in both `workout_completed_forwarded` payload AND `WorkoutSummaryRO.transition_id`.
- **`total_volume` formula** — `Σ (s.reps × s.weight)` over `set_history`. Bodyweight set (`weight=0.0`) contributes 0. Computed at `WorkoutSummaryRO` seal time. Never updated after seal.
- **`set_progress_changed` debounce** — 500ms trailing edge. If `workout_completed` arrives during debounce window → force-flush write (bypass debounce per Rule 7).
- **`dominant_class_changed`** — emit only on genuine flip (not per `set_logged`). Cooldown from Story 004.
- **AC-37 tombstone** — if `acquire_transition_id()` returns a previously-seen ID (ADR-0006 tombstone path), drop the second invocation and log `WST_TXN_COLLIDE_001`. This is best-effort until ADR-0006 Contract 2 is fully ratified.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: `set_progress` + EWMA computation
- [Story 004]: `dominant_class` derivation
- [Story 005]: `get_completed_exercises_count()` distinct logic
- [Story 008]: Persistence snapshot write after seal

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-07 — 6 forwarded signals, poll_* consumed (Rule 1+10)
```
Given: #2 mock emits 7 signals through a full workout
When:  observe WST outbound emissions
Then:  exactly 6 forwarded signals emitted (spy by name):
       workout_started_forwarded, workout_completed_forwarded(completed_at, transition_id),
       workout_summary_available(summary), set_progress_changed(new) [debounced 500ms],
       dominant_class_changed(new) [flip only], phase_changed(from, to)
       poll_failed / poll_recovered NOT forwarded (spy count == 0 for these)
Edge:  assert emission ORDER at completion:
       phase_changed ≺ workout_summary_available ≺ workout_completed_forwarded
       (Rule 10 + NEVER #12: summary BEFORE forwarded)
Edge:  dominant_class_changed emits ONLY on actual flip (no emit when class stable across sets)
```

### AC-15 — total_volume frozen at seal (CF-5)
```
Given: in-progress total_volume == 5000; workout_completed seals WorkoutSummaryRO
When:  late set_logged(.., 5, 60.0) arrives
Then:  WorkoutSummaryRO.total_volume == 5000 (frozen, NOT 5300)
       AND late event dropped per EC-32 (log WST_LATE_SET_001)
```

### AC-21 — final_set_progress + total_volume binding (Formula 4, CF-2)
```
Given: last set_progress == 0.87
       set_history = [5 sets × 100kg × 5reps] + [3 sets × 120kg × 5reps]
When:  workout_completed received
Then:  WorkoutSummaryRO.final_set_progress == 0.87 (CF-2 binding)
       WorkoutSummaryRO.total_volume == 4300.0 (2500 + 1800, Formula 4)
Edge:  bodyweight set (weight 0.0) contributes 0 to total_volume
Edge:  late events after seal do not overwrite either field
```

### AC-24 — append-only prefix consistency fuzz (CF-4)
```
Given: 50 set_logged events
When:  processed sequentially
Then:  at every intermediate snapshot, set_history[0..k-1] is prefix-consistent
       (prior entries deep_equal compared to previous snapshot at same indices)
Edge:  capture .duplicate(true) at each step; assert prefix equality against prior
```

### AC-25 — late-event stress (CF-5)
```
Given: workout_completed; then 20 late set_logged within 1s
When:  read WorkoutSummaryRO
Then:  total_volume unchanged (== value at seal time)
       dropped_late_events_count == 20
       WST_LATE_SET_001 logged 20 times at WARN (each with delay_ms payload)
```

### AC-37 — transition_id collision tombstone (EC-30) [ADR-RATIFICATION-GATED]
```
Given: mock GSM acquire_transition_id() returns same ID twice
When:  second signal uses duplicate ID
Then:  WST drops via tombstone detection; log WST_TXN_COLLIDE_001 at ERROR; no state corruption
Note:  mark test pending() until ADR-0006 Contract 2 tombstone finalization is ratified
       implement best-effort; do NOT block story Done on this AC alone
```

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/workout_state_tracker/test_forwarding_and_summary.gd` — must exist and pass
**Note**: AC-37 test file present but marked `pending()` until ADR-0006 ratified — does not block story Done.

**Status**: [x] Created — `tests/unit/core/workout_state_tracker/test_forwarding_and_summary.gd`

---

## Dependencies

- Depends on: Story 003 (set_progress), Story 004 (dominant_class), Story 005 (RO API) must be DONE
- Unlocks: Story 008 (persistence snapshot triggered on phase_changed), Story 010/011 (downstream consumers)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 5/6 passing (AC-37 ADR-RATIFICATION-GATED — pending() until ADR-0006 Contract 2 ratified)
**Deviations**:
- ADVISORY: `game_state_machine.gd` touched to add public `acquire_transition_id()` wrapper (ADR-0006 Contract 2 requires WST never self-generates — minor scope expansion, architecturally necessary)
- ADVISORY: AC-37 tombstone dedup best-effort; test `pending()` until ADR-0006 Contract 2 ratified + acquire_transition_id DI seam added
- ADVISORY: WST-006-01 latent bug found and fixed (tombstone dedup early-return now schedules `_finalize_workout_idle` to prevent stuck WORKOUT_COMPLETE state)
**New files**: `src/core/workout_summary_ro.gd` (WorkoutSummaryRO immutable resource)
**Test Evidence**: Logic — `tests/unit/core/workout_state_tracker/test_forwarding_and_summary.gd` (10 tests)
**Code Review**: Complete (APPROVED WITH SUGGESTIONS — all fixes applied)
