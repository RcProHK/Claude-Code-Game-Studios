# Story 003: CI Lint Suite B — Boot Order / Signal Lifecycle / State Locality

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-001, TR-enemy-003, TR-enemy-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 Contract 4 + Contract 6
**ADR Decision Summary**: Contract 4 mandates EnemyDirector boot after specific autoloads; Contract 6 mandates all signal connections go through `connect_for_initial_state` helper, never raw `.connect()`.

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [x] AC-04 [Logic|BLOCKING|static]: `tools/ci/check_autoload_boot_order.gd` — scan `project.godot` `[autoload]` section; verify EnemyDirector boot order per **ADR-0008 canonical map** (project.godot is sole ground-truth, F-SETUP-4): EnemyDirector MUST appear AFTER all gameplay-state autoloads it consumes (`PersistenceLayer`, `GameStateMachine`, `PlatformDetect`, `GymSysBackendClient`, `StatSystem`, `AbilitySystem`, `StreakSystem`, `WorkoutStateTracker`, `LootDropSystem`). The hard binding constraint (ADR-0008 Constraint 3 / #13 EC-43 / GDD Rule 9): **`LootDropSystem ≺ EnemyDirector`**. NOTE: presentation-layer autoloads (`AvatarRenderer`, `ParticleSystemWrapper`, `CameraController`, `ScreenEffects`) correctly boot AFTER EnemyDirector (pos 11-14) per ADR-0008 — the GDD Rule 9 prose "after #5/#6/#7" is superseded by ADR-0008 which reclassifies #5/#6/#7 as presentation layer (see architecture.md:439 "EnemyDirector = pos LAST fragility → replaced with pos 10"). Fixture test: modified `project.godot` with EnemyDirector before LootDropSystem → exit 1; correct order (current project.godot) → exit 0.
- [x] AC-10 [Logic|BLOCKING|static]: `tools/ci/check_enemy_director_signal_lifecycle.gd` — scan `enemy_director.gd`; reject any `signal.disconnect(` or `signal.connect(` inside `_physics_process` or `_on_ability_cast` method bodies. All connections must be one-time in `_ready()`. Fixture: positive + negative.
- [x] (Story-level AC) `tools/ci/check_enemy_director_state_locality.gd` — verify 8 state containers declared in EnemyDirector class body (complements AC-01). Fixture: positive (container missing → exit 1) + negative (all present → exit 0).
- [x] (Story-level AC) `tools/ci/check_enemy_director_signal_subscription.gd` — reject any `AbilitySystem.ability_cast.connect(` raw call; must be via `connect_for_initial_state` helper. Fixture: positive + negative.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `check_autoload_boot_order.gd`: parse `project.godot` as text; find `[autoload]` section; extract line-order of autoload names. **Hard exit-1 constraint (must fail CI)**: `LootDropSystem ≺ EnemyDirector` — only this pair must exit-1 on violation (ADR-0008 Constraint 3 / #13 EC-43 / GDD Rule 9 hard binding). **Warn-only (exit-0, print warning)**: EnemyDirector's other predecessor names from current project.godot (`PersistenceLayer`, `GameStateMachine`, `PlatformDetect`, `GymSysBackendClient`, `StatSystem`, `AbilitySystem`, `StreakSystem`, `WorkoutStateTracker`) are advisory-soft — most use `connect_for_initial_state` order-resilient (ADR-0008 Constraint 6), so strict ordering is not required for correctness. Presenting them as exit-1 would cause false-positive regressions if the autoload map is legitimately reordered. Presentation autoloads (`AvatarRenderer`, `ParticleSystemWrapper`, `CameraController`, `ScreenEffects`) boot AFTER EnemyDirector — do NOT require them before it (ADR-0008 reclassified #5/#6/#7 to presentation; GDD Rule 9 prose superseded). NOTE: there is no `CombatResolver` / `TelemetryManager` autoload in project.godot — do NOT require these names.
- `check_enemy_director_signal_lifecycle.gd`: track method scope while scanning; flag any `.connect(` or `.disconnect(` found inside `func _physics_process` or `func _on_ability_cast` bodies.
- `check_enemy_director_state_locality.gd`: scan class body for 8 required var declarations: `_catch_up_queue`, `_anomaly_rate_tracker`, `_enemy_state_pool`, `_killed_dedupe_set`, `_spawn_pool`, `_rng_factory`, `_active_wave`, `_boss_anchor_state`.
- `check_enemy_director_signal_subscription.gd`: regex reject `AbilitySystem\.ability_cast\.connect\(` anywhere not preceded by `connect_for_initial_state` call pattern. Also check `GameStateMachine\.state_changed\.connect\(` for same constraint.
- Fixture files stored in `tests/fixtures/` as `.gd` (follow Story 002 established pattern: `enemy_director_violation_a.gd` / `enemy_director_clean_a.gd`). Use `_b`-suffix or semantic names to avoid colliding with Story 002 fixtures (e.g. `enemy_director_boot_order_violation.gd`, `enemy_director_signal_violation.gd`). GUT inline-regex test in `tests/static/test_enemy_director_ci_lint.gd` (extend/add to existing file). Note: `.gd` files in `tests/fixtures/` are not live scripts — they are text files read by tests via `_read_lines()`, never imported or instantiated.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: CI Lint Suite A (RNG / chokepoint / stat scripts)
- Story 004: CI Lint Suite C (forbidden patterns, move cap, dodge invariant)
- Story 005: Actual signal subscription implementation these lints protect

---

## QA Test Cases

**AC-04**: Given: fixture `project.godot` snippet with EnemyDirector BEFORE LootDropSystem. When: `check_autoload_boot_order.gd` runs. Then: exit code 1. Given: correct fixture (EnemyDirector after LootDropSystem, per current project.godot). Then: exit code 0. (Hard constraint only — `LootDropSystem ≺ EnemyDirector`.)

**AC-10**: Given: `enemy_director.gd` fixture with `GameStateMachine.state_changed.connect(...)` inside `func _physics_process`. When: script runs. Then: exit code 1. Given: clean fixture (connections only in `_ready()`). Then: exit code 0.

**State Locality**: Given: fixture missing `_rng_factory` declaration. When: `check_enemy_director_state_locality.gd` runs. Then: exit code 1. Given: all 8 present. Then: exit code 0.

**Signal Subscription**: Given: fixture with `AbilitySystem.ability_cast.connect(handler)` raw call. When: `check_enemy_director_signal_subscription.gd` runs. Then: exit code 1. Given: `connect_for_initial_state` usage. Then: exit code 0.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 4 CI scripts in `tools/ci/` + fixture files in `tests/fixtures/` + test functions added to `tests/static/test_enemy_director_ci_lint.gd`
**Status**: [x] 4 scripts + 4 fixtures created; test file extended (+14 tests → 39 total); GUT 39/39 PASS (Godot 4.6.2, 2026-05-31)

---

## Completion Notes

**Completed**: 2026-05-31
**Criteria**: 4/4 passing
**Key deliverable**: `check_enemy_director_state_locality.gd` retroactively hardens Story 001 AC-01 — the 8-container locality check is now a BLOCKING CI gate (replaces interim grep).
**AC-04 design note**: Hard exit-1 = ONLY `LootDropSystem ≺ EnemyDirector` (ADR-0008 Constraint 3). Other gameplay predecessors = warn-only exit-0 (ADR-0008 Constraint 6 order-resilient). GDD Rule 9 "boots LAST after #5/#6/#7" prose superseded — presentation autoloads (#5/#6/#7) correctly boot AFTER EnemyDirector per ADR-0008 canonical map.
**Deviations**:
- ADVISORY: Signal lifecycle scope-close last-line edge case (forward risk when Story 006 adds class RNGFactory; doc comment added to script). User accepted.
- ADVISORY: Soft-predecessor warn-only "out-of-order but exit-0" path not tested (ADV-3). Inline-regex approach (project precedent).
- ADVISORY: Exit-code contract 0/1/2 inline-regex only (same as Story 002 WST CI lint precedent).
**Test Evidence**: `tests/static/test_enemy_director_ci_lint.gd` — 39 tests total (14 Story 003 + 11 Story 002 + 14 WST, zero regression). Key test: `test_locality_violation_fixture_is_missing_rng_factory` + `_boss_anchor_state` both detected (ADV-1 fixed post-code-review).
**Code Review**: Complete — LP-CODE-REVIEW APPROVED WITH SUGGESTIONS (0 CRITICAL/MAJOR; 5 MINOR scope/pattern edge cases, Story 006 forward risk).

---

## Dependencies

- Depends on: Story 001 (EnemyDirector source file must exist to lint)
- Unlocks: Story 005 (signal subscription verified by lint), Story 010 (registry data file)
