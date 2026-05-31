# Story 003: CI Lint Suite B — Boot Order / Signal Lifecycle / State Locality

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

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

- [ ] AC-04 [Logic|BLOCKING|static]: `tools/ci/check_autoload_boot_order.gd` — scan `project.godot` `[autoload]` section; verify EnemyDirector listed AFTER #1/#3/#5/#6/#7/#11/#12/#15/#28. Fixture test: modified `project.godot` with EnemyDirector too early → exit 1; correct order → exit 0.
- [ ] AC-10 [Logic|BLOCKING|static]: `tools/ci/check_enemy_director_signal_lifecycle.gd` — scan `enemy_director.gd`; reject any `signal.disconnect(` or `signal.connect(` inside `_physics_process` or `_on_ability_cast` method bodies. All connections must be one-time in `_ready()`. Fixture: positive + negative.
- [ ] (Story-level AC) `tools/ci/check_enemy_director_state_locality.gd` — verify 8 state containers declared in EnemyDirector class body (complements AC-01). Fixture: positive (container missing → exit 1) + negative (all present → exit 0).
- [ ] (Story-level AC) `tools/ci/check_enemy_director_signal_subscription.gd` — reject any `AbilitySystem.ability_cast.connect(` raw call; must be via `connect_for_initial_state` helper. Fixture: positive + negative.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `check_autoload_boot_order.gd`: parse `project.godot` as text; find `[autoload]` section; extract line-order of autoload names; verify `EnemyDirector` appears after `StatSystem`, `AbilitySystem`, `CombatResolver`, `LootDropSystem`, `WorkoutStateTracker`, `ParticleSystemWrapper`, `CameraSystem`, `ScreenEffects`, `TelemetryManager` (or their actual registered names per ADR-0008).
- `check_enemy_director_signal_lifecycle.gd`: track method scope while scanning; flag any `.connect(` or `.disconnect(` found inside `func _physics_process` or `func _on_ability_cast` bodies.
- `check_enemy_director_state_locality.gd`: scan class body for 8 required var declarations: `_catch_up_queue`, `_anomaly_rate_tracker`, `_enemy_state_pool`, `_killed_dedupe_set`, `_spawn_pool`, `_rng_factory`, `_active_wave`, `_boss_anchor_state`.
- `check_enemy_director_signal_subscription.gd`: regex reject `AbilitySystem\.ability_cast\.connect\(` anywhere not preceded by `connect_for_initial_state` call pattern. Also check `GameStateMachine\.state_changed\.connect\(` for same constraint.
- All fixture files stored in `tests/ci_fixtures/` with `.gd.txt` extension (not `.gd` — prevents Godot from parsing them as live scripts).

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: CI Lint Suite A (RNG / chokepoint / stat scripts)
- Story 004: CI Lint Suite C (forbidden patterns, move cap, dodge invariant)
- Story 005: Actual signal subscription implementation these lints protect

---

## QA Test Cases

**AC-04**: Given: `project.godot` fixture with EnemyDirector at position 2 (before StatSystem). When: `check_autoload_boot_order.gd` runs. Then: exit code 1. Given: `project.godot` fixture with correct ordering. Then: exit code 0.

**AC-10**: Given: `enemy_director.gd` fixture with `GameStateMachine.state_changed.connect(...)` inside `func _physics_process`. When: script runs. Then: exit code 1. Given: clean fixture (connections only in `_ready()`). Then: exit code 0.

**State Locality**: Given: fixture missing `_rng_factory` declaration. When: `check_enemy_director_state_locality.gd` runs. Then: exit code 1. Given: all 8 present. Then: exit code 0.

**Signal Subscription**: Given: fixture with `AbilitySystem.ability_cast.connect(handler)` raw call. When: `check_enemy_director_signal_subscription.gd` runs. Then: exit code 1. Given: `connect_for_initial_state` usage. Then: exit code 0.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 4 CI scripts in `tools/ci/` + fixture files in `tests/ci_fixtures/`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (EnemyDirector source file must exist to lint)
- Unlocks: Story 005 (signal subscription verified by lint), Story 010 (registry data file)
