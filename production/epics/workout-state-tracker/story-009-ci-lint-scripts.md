# Story 009: CI Lint Scripts + Static Analysis

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: 2h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirement**: `TR-wst-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Proposed — existing CI script pattern); ADR-0006 Contracts 12/13 (enforce NEVER patterns)
**ADR Decision Summary**: ADR-0001 establishes the CI script pattern (`tools/ci/check_*.gd`). WST adds three scripts following the same pattern. ADR-0006 locks the NEVER patterns that these scripts enforce.

**ADR: N/A for story implementation** — CI script files are pure tooling, no architectural pattern required.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI scripts use `--headless --script` mode (Godot CLI). Pattern matches existing `tools/ci/check_camera_callers.gd` etc.

**Control Manifest Rules**:
- Required: CI scripts follow existing pattern in `tools/ci/` (grep-based, exit non-zero on violation)
- Required: Scripts support `# ci:allow-wst-mutation` whitelist comment for test files
- Required: Positive fixture (planted violation file) to prove detection works (not just absence check)
- Forbidden: Any `WorkoutStateTracker.(set_|_)` outside `src/core/workout_state_tracker.gd`
- Forbidden: `PersistenceLayer.write(["']wst\.` outside `src/core/workout_state_tracker.gd`
- Forbidden: `Stat.get_*` reference inside `src/core/workout_state_tracker.gd`
- Forbidden: `preload(..).new()` instantiation of WST (must use autoload reference)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-06** (Rule 14 CI lint): GIVEN full repo `src/`, WHEN execute `tools/ci/check_workout_state_caller.gd` + `tools/ci/check_wst_namespace.gd`, THEN (a) `WorkoutStateTracker\.(set_|_)` matches 0 locations outside `src/core/workout_state_tracker.gd`; (b) `PersistenceLayer.write\(["']wst\.` matches 0 locations outside same file; any match → CI build fail (non-zero exit). Test files with `# ci:allow-wst-mutation` → bypass.
- [ ] **AC-17** (Rule 15 + Rule 16): GIVEN repo, WHEN run `tools/ci/check_wst_singleton_and_nevers.gd`, THEN (a) all WST calls use `WorkoutStateTracker.xxx` (autoload name), not `preload(..).new()`; (b) `_workout_phase =` / `_dominant_class =` outside autoload file → CI fail; (c) `Stat.get_*` reference inside `src/core/workout_state_tracker.gd` → CI fail (Rule 16 NEVER #6).

---

## Implementation Notes

*CI scripts follow existing `tools/ci/` pattern (check_camera_callers.gd, check_platform_detect_callers.gd):*

- **`check_workout_state_caller.gd`** — grep patterns:
  - `WorkoutStateTracker\.(set_|_)` outside `src/core/workout_state_tracker.gd` → FAIL
  - `assignments to WorkoutStateTracker.*` → FAIL
  - Whitelist: `WorkoutStateTracker.get_*()` and signal `.connect` → pass
  - Whitelist: `# ci:allow-wst-mutation` comment in test files → bypass
- **`check_wst_namespace.gd`** — grep pattern:
  - `PersistenceLayer\.write\(["']wst\.` outside `src/core/workout_state_tracker.gd` → FAIL
  - Only #9 writes `wst.*` namespace
- **`check_wst_singleton_and_nevers.gd`** — grep patterns:
  - `preload\(.*workout_state_tracker.*\)\.new\(\)` anywhere → FAIL
  - `_workout_phase\s*=` outside autoload source → FAIL
  - `_dominant_class\s*=` outside autoload source → FAIL
  - `Stat\.get_` inside `src/core/workout_state_tracker.gd` → FAIL
- **Test runner**: `tests/static/test_wst_ci_lint.gd` — calls each script, asserts exit code 0 on clean repo, asserts non-zero on planted-violation fixture.
- **Planted-violation fixtures** — create `tests/fixtures/wst_ci_violation_sample.gd` with one deliberate violation per rule (annotated `# ci:violation-fixture`). Scripts MUST detect these (proves detection, not just absence).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 005]: The actual closed RO API that these scripts enforce
- [Story 007]: The `Stat.apply_stat_delta` one-way call that `Stat.get_*` ban protects

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-06 — closed-API + namespace CI lint
```
Given: full src/ tree (clean — no violations)
When:  run tools/ci/check_workout_state_caller.gd + check_wst_namespace.gd
Then:  (a) regex WorkoutStateTracker\.(set_|_) matches 0 outside source file → exit 0
       (b) regex PersistenceLayer.write(["']wst\. matches 0 outside source file → exit 0
Edge:  positive fixture test — plant violation in tests/fixtures/wst_ci_violation_sample.gd
       → scripts MUST report non-zero exit (proves detection works, not just absence)
Edge:  whitelist: WorkoutStateTracker.get_*() anywhere → pass (exit 0)
Edge:  whitelist: test file with # ci:allow-wst-mutation comment → bypass that file
```

### AC-17 — autoload-ref + NEVER sweep
```
Given: repo
When:  run tools/ci/check_wst_singleton_and_nevers.gd
Then:  (a) preload(..).new() instantiation → exit non-zero
       (b) _workout_phase = outside autoload source → exit non-zero
       (c) Stat.get_* inside workout_state_tracker.gd → exit non-zero
       clean repo → exit 0 for all three checks
Edge:  each rule needs a planted-violation fixture (proves detection, not just absence)
Edge:  WorkoutStateTracker.get_dominant_ability_class() in any file → NOT flagged (allowed read)
```

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check pass — run `tools/ci/check_workout_state_caller.gd`, `check_wst_namespace.gd`, `check_wst_singleton_and_nevers.gd` against clean repo. Document in `production/qa/smoke-*.md`.
**Additionally**: `tests/static/test_wst_ci_lint.gd` — automated static test wrapper

**Status**: [x] Smoke check: `production/qa/smoke-wst-ci-lint-2026-05-31.md` · Static tests: `tests/static/test_wst_ci_lint.gd`

---

## Dependencies

- Depends on: Story 005 (closed API surface defined and in place) must be DONE before lint scripts can find real violations
- Unlocks: All other stories validated by these lint rules (CI gate for full epic)

---

## Completion Notes
**Completed**: 2026-05-31
**Criteria**: 2/2 passing
**Deviations**: None
**Test Evidence**: Config/Data — smoke check `production/qa/smoke-wst-ci-lint-2026-05-31.md` + static tests `tests/static/test_wst_ci_lint.gd` (13 tests)
**Code Review**: Complete (LP-CODE-REVIEW — CHANGES REQUIRED → 3 blocking issues fixed: whole-line whitelist removed, set_ explicit violation + _dominant_class= write added to fixture, detection tests added)
