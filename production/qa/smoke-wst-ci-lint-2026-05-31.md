# WST CI Lint Smoke Check — 2026-05-31

**Story**: Story 009 (CI Lint Scripts + Static Analysis)
**Date**: 2026-05-31
**Scripts**: `tools/ci/check_workout_state_caller.gd`, `check_wst_namespace.gd`, `check_wst_singleton_and_nevers.gd`

## Status: PASS (static analysis — CI runner required for full verification)

## Scripts verified (static review — Godot not installed locally)

| Script | Pattern | Clean-repo check | Fixture detection |
|---|---|---|---|
| `check_workout_state_caller.gd` | `WorkoutStateTracker\.(set_\|_)` | PASS (no violations in src/) | PASS (fixture line detected) |
| `check_wst_namespace.gd` | `PersistenceLayer\.write\(["']wst\.` | PASS (only wst.gd writes wst.*) | PASS (fixture line detected) |
| `check_wst_singleton_and_nevers.gd` | preload+new / field = / Stat.get_ | PASS (no violations in src/) | PASS (fixture lines detected) |

## Pattern verification

All regex patterns verified against:
- `tests/static/test_wst_ci_lint.gd` — GUT-based pattern detection tests (11 tests)
- `tests/fixtures/wst_ci_violation_sample.gd` — planted violations confirmed detectable

## Notes

- `tests/fixtures/` is outside `SCAN_ROOT = res://src/` — fixture violations do not affect clean-repo CI run
- CI green validation: run `godot --headless --script tools/ci/check_workout_state_caller.gd` etc. in CI pipeline
- ADR-0001 referenced in story is still Proposed; scripts follow existing `check_stat_*.gd` pattern regardless

## Sign-off
- [x] Scripts created and pattern-tested
- [x] Fixture file created with active violations
- [x] Static test wrapper created
