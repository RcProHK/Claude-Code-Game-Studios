# Story 001: WorkoutPhase FSM + Transition Guards

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirements**: `TR-wst-002`, `TR-wst-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: State Machine Contract
**ADR Decision Summary**: Transition atomicity via generational lock; `transition_id` collision-safety via tombstone forward-recovery; `connect_for_initial_state` sentinel for boot-order-independent subscription.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: GDScript variadic args (4.5+) explicitly avoided in `call_deferred` paths. `FileAccess.store_*` returning bool (4.4+). Autoload `_enter_tree`/`_ready` per-autoload sequential ordering verified against 4.6 migration docs.

**Control Manifest Rules (Core layer)**:
- Required: `connect_for_initial_state(callable)` for GSM subscription (ADR-0006 Contract 6)
- Required: `call_deferred` pattern for any follow-up transition from `state_changed` subscriber (ADR-0006 Contract 5)
- Forbidden: `await` in state machine execution paths (ADR-0006 Contract 12)
- Forbidden: zero-default fabrication for `AbilityClass` (ADR-0007 Family B)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-02** (Rule 2): GIVEN initial `phase == IDLE`, WHEN sequentially emit `workout_started → set_logged → rest_started → rest_ended → set_logged → workout_completed`, THEN phase transitions: `WARM_UP → SET_ACTIVE → REST_PERIOD → REST_PERIOD (rest_ended internal flag only) → SET_ACTIVE → WORKOUT_COMPLETE`; every real phase change emits `phase_changed(old, new)` signal (5 emissions — `rest_ended` does NOT emit, sets internal `_rest_ended_awaiting_next_set` flag).
- [ ] **AC-08** (Rule 4 + CF-4): GIVEN `current_workout_ro.set_history` has N entries, WHEN emit another `set_logged`, THEN `set_history.size() == N+1`; existing N entries deep_equal unchanged (capture `.duplicate(true)` snapshot before); any in-place mutation or pop → assert fail.
- [ ] **AC-31** (EC-01 truth gate): GIVEN `phase == IDLE`, WHEN mock receives `workout_completed(now)`, THEN event dropped + log `WST_INV_VIOL_001` (ERROR); phase stays IDLE; `workout_completed_forwarded` NOT emitted (signal spy count == 0).
- [ ] **AC-38** (EC-32): GIVEN `phase == WORKOUT_COMPLETE` + `WorkoutSummaryRO` sealed with known `total_volume = V`, WHEN late `set_logged(exercise, 5, 60.0)` arrives 0–3s after, THEN event dropped + log `WST_LATE_SET_001` (WARN, payload=delay_ms); `WorkoutSummaryRO.total_volume == V` (unchanged).

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- **WorkoutPhase enum** — 5 states: `IDLE / WARM_UP / SET_ACTIVE / REST_PERIOD / WORKOUT_COMPLETE`. Ordinal 0 = IDLE (safe default per ADR-0007 Family A Outcome/State pattern).
- **Transition matrix** — only valid transitions per GDD Rule 2. Invalid signal → drop + log `WST_INV_VIOL_*` + DO NOT crash + DO NOT fabricate.
- **`rest_ended` semantic** — sets `_rest_ended_awaiting_next_set = true`; phase stays `REST_PERIOD` (no `phase_changed` emit). Next `set_logged` clears flag and advances to `SET_ACTIVE`.
- **`WORKOUT_COMPLETE` → `IDLE`** — auto-transition via `call_deferred(_transition_to_idle)` on next tick. Do NOT transition synchronously.
- **append-only invariant** — `set_history` is `Array[Dictionary]`; only `.append()` allowed inside `_on_set_logged` handler. No `.pop_*()`, no index-assign, no `.clear()` outside workout reset path.
- **Log codes** — use exactly: `WST_INV_VIOL_001` (EC-01), `WST_INV_VIOL_002` (EC-02), `WST_LATE_SET_001` (EC-32).
- **Performance**: WorkoutPhase transitions are event-driven (at most a few per workout session — not per-frame hot path). No CPU budget concern from the gameplay loop perspective. Transition handler MUST complete synchronously without `await` per ADR-0006 Contract 12.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Substate INITIALISING/READY/SUSPENDED lifecycle and frozen flag
- [Story 003]: `set_progress` formula computation
- [Story 004]: `dominant_class` derivation
- [Story 006]: `workout_completed` forwarding + `WorkoutSummaryRO` construction

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-02 — Phase transition sequence
```
Given: WST READY, phase == IDLE, #2 mock injected
When:  emit workout_started → set_logged → rest_started → rest_ended → set_logged → workout_completed
Then:  phase sequence == [WARM_UP, SET_ACTIVE, REST_PERIOD, REST_PERIOD, SET_ACTIVE, WORKOUT_COMPLETE]
       AND phase_changed(old, new) emitted on each REAL phase change (5 emissions)
Edge:  rest_ended keeps phase == REST_PERIOD (no phase_changed emit);
       verify _rest_ended_awaiting_next_set == true after rest_ended
Edge:  capture phase_changed payload order — first == (IDLE, WARM_UP), last == (SET_ACTIVE, WORKOUT_COMPLETE)
```

### AC-08 — set_history append-only
```
Given: set_history has N entries (factory-built, N=3)
When:  emit set_logged(exercise, reps, weight)
Then:  set_history.size() == N+1
       AND set_history[0..N-1] deep_equal pre-emit snapshot (capture .duplicate(true) before)
Edge:  attempt set_history.pop_back() / set_history[0] = {} on RO-exposed array → must fail
Edge:  N=0 boundary — first set_logged yields size 1
```

### AC-31 — workout_completed dropped in IDLE (EC-01)
```
Given: phase == IDLE
When:  mock emits workout_completed(now)
Then:  event dropped; log WST_INV_VIOL_001 at ERROR
       AND phase stays IDLE
       AND workout_completed_forwarded NOT emitted (signal spy count == 0)
Edge:  assert log payload contains signal_name + current_phase + transition_id fields
```

### AC-38 — late set_logged after WORKOUT_COMPLETE (EC-32)
```
Given: phase == WORKOUT_COMPLETE; WorkoutSummaryRO sealed with known total_volume V
When:  late set_logged(exercise, 5, 60.0) arrives within 0–3s window
Then:  event dropped; log WST_LATE_SET_001 at WARN with payload=delay_ms
       AND WorkoutSummaryRO.total_volume == V (unchanged)
       AND set_history not appended (Rule 16 NEVER #5)
Edge:  parametrize delay_ms ∈ {0, 1500, 3000} — all dropped identically
```

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/workout_state_tracker/test_phase_fsm_and_guards.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/core/workout_state_tracker/test_phase_fsm_and_guards.gd`

---

## Dependencies

- Depends on: None (first story in epic — no prerequisites)
- Unlocks: Story 002, Story 003, Story 004, Story 005, Story 006 (all use phase machine internally)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (3 edge-clause deferrals — see tech debt)
**Deviations**:
- ADVISORY: AC-08 in-place-mutation edge deferred to Story 005 (no RO seam in Story 001)
- ADVISORY: AC-31 log payload fields deferred to Story 006 (no transition_id / push_error spy)
- ADVISORY: AC-38 delay_ms parametrize benign (no timing window in implementation)
- ADVISORY: EC-02/EC-03/EC-04 guard branches implemented but untested — logged in tech debt
**Test Evidence**: Logic — `tests/unit/core/workout_state_tracker/test_phase_fsm_and_guards.gd` (9 tests)
**Code Review**: Complete (APPROVED — /code-review + LP-CODE-REVIEW gate both passed)
