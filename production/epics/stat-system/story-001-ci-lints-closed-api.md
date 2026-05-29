# Story 001: CI Lints — Closed Mutation API Enforcement

> **Epic**: Stat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Static
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-002`, `TR-stat-016`
*(TR-stat-002: Closed mutation API — no direct `_base` write; caller whitelist CI lint. TR-stat-016: DEBUG_OVERRIDE CI lint catches `src/` usage)*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — Contract 12 (no `await` + CI-enforced chokepoints)
**ADR Decision Summary**: All mutation paths are funnelled through a single chokepoint; CI lints enforce this statically so violations cannot reach main.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI lints use `rg --glob "*.gd"` (NOT `rg --type gdscript` — that type is invalid in ripgrep and will silently error). All 4 lints must use the correct flag.

**Control Manifest Rules (Core layer)**:
- Required: CI caller whitelist enforced (`check_stat_mutation_callers.gd`) — only `src/feature/pr_detection.gd` (#18), `src/core/workout_state_tracker.gd` (#9), `src/feature/equipment_inventory.gd` (#17) may call `apply_stat_delta` — source: ADR-0007 + GDD Rule 4
- Forbidden: Never allow `StatSystem._base[` writes outside `src/autoload/stat_system.gd` — source: GDD Rule 2
- Forbidden: `StatSource.DEBUG_OVERRIDE` in `src/` on release branch — source: GDD Rule 10, FR-3

---

## Acceptance Criteria

- [ ] **AC-02** — GIVEN any `src/` file (excluding `src/autoload/stat_system.gd`) contains literal `StatSystem._base[` OR `StatSystem._equipment_modifiers[`, WHEN CI lint `tools/ci/check_stat_internal_field_access.gd` runs, THEN build fails, exit code ≠ 0, error message identifies offending file + line number.
- [ ] **AC-03** — GIVEN any `src/` file (excluding `src/autoload/workout_state_tracker.gd`, `src/feature/pr_detection.gd`, `src/feature/equipment_inventory.gd`, and `tests/`) contains `StatSystem.apply_stat_delta(`, WHEN CI lint `tools/ci/check_stat_mutation_callers.gd` runs, THEN build fails, identifying unauthorized caller file path.
- [ ] **AC-14** — GIVEN any `src/` file (excluding `tests/` and editor-only marker paths) contains literal `StatSource.DEBUG_OVERRIDE`, WHEN CI lint `tools/ci/check_debug_override_calls.gd` runs on release branch (`main` / `release/*`), THEN build fails.
- [ ] **AC-34** — GIVEN any `src/` file (excluding `src/autoload/stat_system.gd` and `tests/`) contains `.connect(` with `"stat_changed"` (plain connect bypassing Contract 6 helper), WHEN CI lint `tools/ci/check_stat_changed_connect.gd` runs, THEN build fails with message: "Use `connect_for_initial_state(callable)` instead of plain `.connect` for stat_changed signal — see ADR-006 Contract 6".

---

## Implementation Notes

*From GDD Rules 2, 4, 10 + ADR-0006 Contract 12:*

1. **`check_stat_internal_field_access.gd`** — grep `StatSystem\._base\[` and `StatSystem\._equipment_modifiers\[` across `src/`. Exclude `src/autoload/stat_system.gd` itself. Exit 1 on any match.
2. **`check_stat_mutation_callers.gd`** — grep `StatSystem\.apply_stat_delta\(` across `src/`. Exclude the three whitelisted caller paths + `tests/`. Exit 1 on any match outside whitelist.
3. **`check_debug_override_calls.gd`** — grep `StatSource\.DEBUG_OVERRIDE` across `src/`. Exclude `tests/` and files with `OS.has_feature("editor")` guard. Exit 1 on release branches. Exit 0 on non-release (debug builds may use it).
4. **`check_stat_changed_connect.gd`** — grep `\.connect\(` with nearby `"stat_changed"` (may need multi-token scan). Exclude `src/autoload/stat_system.gd` (signal owner) and `tests/`. Exit 1 on match with clear migration message.
5. **CI integration**: Add all 4 lints to `.github/workflows/tests.yml` shell-lint step (same loop as existing `tools/ci/*.sh` lints). Each must be non-vacuous — include a fixture test or a guard that exits 2 (internal error) if the target directory is absent.
6. **`rg` flag**: Always use `--glob "*.gd"` NOT `--type gdscript` — the latter is an invalid ripgrep type that silently errors.

---

## Out of Scope

- Story 002: StatSource enum implementation (what the lints guard)
- Story 004: DEBUG_OVERRIDE runtime guard in `apply_stat_delta` body (AC-13)
- The actual `stat_system.gd` implementation — lints only

---

## QA Test Cases

**Story Type**: Static
**Required evidence**: All 4 CI lint scripts — must exist, be non-vacuous, and exit 0 on clean code, exit 1 on violation.

- **AC-02**: Internal field access lint
  - Given: `src/some_system.gd` contains `StatSystem._base["str"] = 99`
  - When: `check_stat_internal_field_access.gd` runs
  - Then: Exit 1, error identifies `src/some_system.gd`
  - Edge cases: Lint passes on `src/autoload/stat_system.gd` itself; comment-line occurrence `# StatSystem._base[` must not false-positive

- **AC-03**: Caller whitelist lint
  - Given: `src/gameplay/some_other_system.gd` contains `StatSystem.apply_stat_delta(`
  - When: `check_stat_mutation_callers.gd` runs
  - Then: Exit 1, unauthorized caller identified
  - Edge cases: `src/core/workout_state_tracker.gd` calling `apply_stat_delta` → exit 0 (whitelisted); `tests/` calling → exit 0 (excluded)

- **AC-14**: DEBUG_OVERRIDE lint (release branch)
  - Given: `src/autoload/some_system.gd` contains `StatSource.DEBUG_OVERRIDE`
  - When: Lint runs on `main` branch
  - Then: Exit 1
  - Edge cases: Same file in `tests/` → exit 0; file guarded by `OS.has_feature("editor")` → exit 0 (editor-only)

- **AC-34**: Plain `.connect` lint
  - Given: `src/ui/hud.gd` contains `stat_system.stat_changed.connect(my_handler)`
  - When: `check_stat_changed_connect.gd` runs
  - Then: Exit 1 with migration message pointing to `connect_for_initial_state`
  - Edge cases: `src/autoload/stat_system.gd` connecting its own signal for internal purposes → exit 0; `connect_for_initial_state(my_handler)` → exit 0

---

## Test Evidence

**Story Type**: Static
**Required evidence**: `tools/ci/check_stat_internal_field_access.gd`, `check_stat_mutation_callers.gd`, `check_debug_override_calls.gd`, `check_stat_changed_connect.gd` — all must exist and pass in CI

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (CI infrastructure — first story, no runtime code required)
- Unlocks: Story 002 (runtime implementation — lints must exist before code is written so violations are caught immediately)
