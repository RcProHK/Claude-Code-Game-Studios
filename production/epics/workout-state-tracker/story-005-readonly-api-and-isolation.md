# Story 005: Read-Only Query API + workout_id Isolation + Distinct Count

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirements**: `TR-wst-005`, `TR-wst-008`, `TR-wst-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation (primary)**: ADR-0006: State Machine Contract
**ADR Decision Summary**: `WorkoutSnapshotRO` / `WorkoutSummaryRO` are immutable `SerializableResource` subclasses (Contract 3); `resource_local_to_scene = false`; consumer mutation attempts fail-fast.

**Secondary ADRs**: ADR-0007 (AbilityClass canonical enum), ADR-0009 (Signal Payload Schema — minimal + intrinsic, no ambient context in payloads)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Resource` field immutability enforced via GDScript `set()` override returning `false`. `get_method_list()` introspection stable since Godot 4.0.

**Control Manifest Rules (Core layer)**:
- Required: `WorkoutSnapshotRO` / `WorkoutSummaryRO` must extend `SerializableResource` with `to_dict()` / `from_dict()` (ADR-0006 Contract 3)
- Required: Signal payloads minimal + intrinsic — no ambient context (workout_id, GSM state) stuffed in payload (ADR-0009 §1)
- Required: Handlers needing ambient context must late-bind via `WorkoutStateTracker.get_active_workout_id()` API + explicit null branch (ADR-0009 §2)
- Forbidden: `preload(..).new()` instantiation of WST — always use `WorkoutStateTracker.xxx` autoload reference (Rule 16)
- Forbidden: `completed_exercises_count` using set-count instead of distinct `exercise_id` count (GDD CI-5)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-05** (Rule 1): GIVEN WST in any state, WHEN call `get_current_phase()`, `get_dominant_ability_class()`, `get_set_progress()`, `get_completed_exercises_count()`, `get_workout_snapshot()`, THEN all return immutable RO (mutating a field triggers GDScript error); `get_method_list()` contains NO public method matching `^(set_|mutate_|force_)`.
- [ ] **AC-09** (Rule 11.1): GIVEN first workout `id=W1` complete + `previous_dominant_class` locked, WHEN second `workout_started` fires (new client-derived workout_id), THEN `_current_workout_id` updated; W1 `WorkoutSummaryRO.transition_id` preserved; `set_history` resets empty; W1 and W2 data do not cross-contaminate.
- [ ] **AC-14** (Rule 1 + CI-5): GIVEN same workout emits 5 `set_logged` with `exercise_id ∈ {E1, E1, E2, E1, E3}`, WHEN read `get_completed_exercises_count()`, THEN value == 3 (distinct), NOT 5 (set count).
- [ ] **AC-30** (CI-5 stress): GIVEN 100 sets drawn from pool of 10 distinct `exercise_id`s (seeded), WHEN complete, THEN `get_completed_exercises_count() == 10`; never exceeds pool cardinality at any intermediate point; 1000-sequence fuzz harness.

---

## Implementation Notes

*Derived from ADR-0006 Contract 3 + ADR-0009 + GDD Rule 1/11.1:*

- **5 read-only queries** — all O(1) cached reads. No computation in the getter body.
  - `get_current_phase() -> WorkoutPhase`
  - `get_dominant_ability_class() -> AbilityClass`
  - `get_set_progress() -> float`
  - `get_completed_exercises_count() -> int` (distinct `exercise_id` count — use `Set`/`Dictionary` dedup)
  - `get_workout_snapshot() -> WorkoutSnapshotRO`
- **Immutable RO resources** — `WorkoutSnapshotRO` / `WorkoutSummaryRO` extend `SerializableResource`. Override `_set(property, value)` to return `false` for all public fields (fail-fast on mutation attempt).
- **`completed_exercises_count`** — distinct `exercise_id` count, maintained via `_completed_exercises: Dictionary` keyed by `exercise_id`. Increment a key once on first occurrence per workout. Reset on new workout.
- **workout_id lifecycle** — on `workout_started`: client-derive `_current_workout_id = "wst-%d-%d" % [Time.get_unix_time_from_system(), randi() % 10000]`; reset `set_history = []`; reset `_completed_exercises = {}`; preserve `previous_dominant_class`. Old `WorkoutSummaryRO` (if any) becomes immutable archive — do NOT overwrite.
- **ADR-0009 compliance** — `WorkoutSnapshotRO` carries only derived state snapshot (NOT mutable workout_id in every signal payload). Callers needing `workout_id` call `WorkoutStateTracker.get_current_workout_id()` explicitly at handler time.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: `set_progress` computation logic
- [Story 004]: `dominant_class` derivation logic
- [Story 006]: `workout_completed_forwarded` + `WorkoutSummaryRO` construction
- [Story 009]: CI lint scripts that enforce closed-API rule

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-05 — closed read-only API surface (Rule 1)
```
Given: WST in any state
When:  call each of the 5 public query methods
Then:  each returns valid value (no error on call)
       attempting to mutate a returned WorkoutSnapshotRO field triggers GDScript error
       get_method_list() contains NO method matching regex ^(set_|mutate_|force_)
Edge:  WorkoutSnapshotRO / WorkoutSummaryRO: confirm _set() override returns false for fields
```

### AC-09 — workout_id lifecycle isolation (Rule 11.1)
```
Given: workout W1 complete; previous_dominant_class locked; W1 WorkoutSummaryRO.transition_id == TXN1
When:  second workout_started fires (new client-derived workout_id)
Then:  _current_workout_id updated (≠ W1 id)
       AND W1 summary.transition_id == TXN1 preserved (not overwritten)
       AND set_history reset to empty []
Edge:  W2 set_logged does not appear in any W1-scoped query or summary
Edge:  _completed_exercises dict resets to {} on new workout_started
```

### AC-14 — distinct exercise count (CI-5)
```
Given: 5 set_logged with exercise_id ∈ {E1, E1, E2, E1, E3}
When:  get_completed_exercises_count()
Then:  == 3 (distinct), NOT 5 (set count)
Edge:  0 sets → count 0; single exercise ×5 → count 1
```

### AC-30 — distinct count stress (CI-5 fuzz)
```
Given: 100 sets drawn from pool of 10 distinct exercise_ids (FIXED SEED = 137)
When:  complete all 100 sets
Then:  get_completed_exercises_count() == 10 (== pool cardinality)
       count never exceeds pool cardinality at any intermediate point
Edge:  1000-sequence fuzz harness; each sequence asserts count <= distinct_ids_seen_so_far
Note:  seed is FIXTURE CONSTANT — not runtime random (testing-standards determinism)
```

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/workout_state_tracker/test_readonly_api_and_isolation.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/core/workout_state_tracker/test_readonly_api_and_isolation.gd`

---

## Dependencies

- Depends on: Story 003 (set_progress), Story 004 (dominant_class) must be DONE (queries surface their cached values)
- Unlocks: Story 006 (WorkoutSummaryRO construction), Story 009 (CI lint validates this API surface)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-09b WorkoutSummaryRO.transition_id deferred to Story 006)
**Deviations**:
- ADVISORY: AC-09b (WorkoutSummaryRO.transition_id preservation) deferred to Story 006 — type does not exist yet
- Code review fixes applied: WorkoutSnapshotRO immutability via inline setter/getter (not _set() override), get_script_method_list() for closed-API check, enum string-name serialization (ADR-0007), from_dict() seals on return
**New file**: `src/core/workout_snapshot_ro.gd` (WorkoutSnapshotRO immutable SerializableResource)
**Test Evidence**: Logic — `tests/unit/core/workout_state_tracker/test_readonly_api_and_isolation.gd` (14 tests)
**Code Review**: Complete (APPROVED — 1 CRITICAL + 1 QA-BLOCKING + 2 WARNING all fixed)
