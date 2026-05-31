# Story 011: [BLOCKED] Boss Anchor CI-1/CI-2 Integration + Sub-500ms Test

> **Epic**: Workout State Tracker
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4h (when unblocked)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Blockers

**BLOCKED: ADR-0002 Proposed** — GymSys Integration Protocol signal payload contract not locked. Boss anchor tests require a real #14 EnemyDirector instance (mocked render layer only), which in turn depends on locked #2 signal contracts.

**BLOCKED: #14 EnemyDirector epic not yet implemented** — AC-26/AC-27 require `#14 real instance (mocked render layer)` + `#14 spy signal _boss_anchor_pre_spawn_started`. Story cannot be written to DONE until #14 epic is complete.

**To unblock**: (1) Run `/architecture-decision` to advance ADR-0002 to Accepted. (2) Complete #14 EnemyDirector epic. Then remove the BLOCKED status and proceed.

---

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirement**: `TR-wst-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Proposed ⚠️) + ADR-0006 Contract 2
**ADR Decision Summary**: CI-1 binding — `set_progress >= 0.8` triggers #14 boss anchor pre-spawn pipeline. CI-2 — when `set_progress_is_estimated == true` AND < 0.8, #14 uses fallback heuristic (`reps_completed_in_set >= ceil(planned_reps × 0.5)`).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Sub-500ms p95 latency test (AC-41) can run with mock #14 render in CI headless mode. On-device frame-timing at MVP gate = DEFERRED to on-device manual.

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-26** (CI-1): GIVEN WST + #14 real instance (mocked render layer), WHEN WST forwards `set_progress_changed(0.82)`, THEN #14 boss anchor pre-spawn pipeline triggers (observable via #14 spy signal `_boss_anchor_pre_spawn_started`); `set_progress_changed(0.78)` → NOT triggered.
- [ ] **AC-27** (CI-2): GIVEN `WorkoutSnapshotRO.set_progress_is_estimated == true` AND `set_progress < 0.8`, WHEN #14 4Hz tick queries, THEN #14 activates fallback `reps_completed_in_set >= ceil(planned_reps × 0.5)` path; #9 has zero responsibility for fallback computation.
- [ ] **AC-41** (Falsifiable Test #2 — CI portion): GIVEN scripted workout ending (set_progress crossing 0.8 → workout_completed 30s later), WHEN measure `workout_completed_forwarded` emit → boss visible-on-screen frame, THEN p95 ≤ 500ms (100 trials, automated harness, mock #14 render). *(MVP gate on-device frame-timing = DEFERRED.)*

---

## Implementation Notes

*(Document here when unblocked — reference #14 EnemyDirector GDD Rule 12/13 for boss anchor pre-spawn interface.)*

- **CI-1 threshold** — `pre_spawn_threshold = 0.8` (registry-locked, owned by #14)
- **CI-2 fallback** — `pre_spawn_fallback_reps_frac = 0.5` (registry-locked, owned by #14)
- **Sub-500ms architecture** — pre-spawn at `set_progress > 0.8`, commit on `workout_completed` arrival. Eliminates ≥500ms instantiation spike at final rep.

---

## Out of Scope

*(When unblocked, do not implement #14's boss anchor logic here — only verify the #9→#14 data flow interface.)*

---

## QA Test Cases

*(Test specs ready — implement when unblocked.)*

### AC-26 — CI-1: set_progress ≥ 0.8 → boss anchor trigger
```
Given: WST + #14 real instance (mocked render layer); #14 spy on _boss_anchor_pre_spawn_started
When:  WST emits set_progress_changed(0.82)
Then:  #14 boss anchor pre-spawn pipeline triggers (spy records 1 event)
When:  WST emits set_progress_changed(0.78)
Then:  boss anchor NOT triggered (spy records 0 events)
Edge:  threshold exactly 0.8 → check boundary (≥ 0.8 triggers, < 0.8 does not)
```

### AC-27 — CI-2: unreliable set_progress → #14 fallback
```
Given: WorkoutSnapshotRO.set_progress_is_estimated == true
       set_progress < 0.8 consistently
When:  #14 4Hz tick queries WST
Then:  #14 activates fallback reps_completed_in_set >= ceil(planned_reps × 0.5) path
       #9 spy confirms set_progress computation NOT changed by this fallback
       (zero responsibility in #9 for fallback)
```

### AC-41 — Falsifiable Test #2: sub-500ms p95 [CI mock portion]
```
Given: scripted workout (set_progress crosses 0.8; workout_completed arrives 30s later)
       mock #14 render layer records frame timestamp on boss-visible signal
When:  measure workout_completed_forwarded emit timestamp → boss_visible_frame timestamp
       run 100 trials
Then:  p95 latency ≤ 500ms
Deferred: on-device frame-timing at MVP gate = DEFERRED to manual playtest evidence
```

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/core/workout_state_tracker/test_ci1_boss_anchor_trigger.gd` — must exist and pass (when unblocked)

**Status**: [ ] BLOCKED — not started

---

## Dependencies

- Depends on: Story 001-010 must be DONE; #14 EnemyDirector epic complete; ADR-0002 Accepted
- Unlocks: Story 012 (anti-fabrication chain full validation)
