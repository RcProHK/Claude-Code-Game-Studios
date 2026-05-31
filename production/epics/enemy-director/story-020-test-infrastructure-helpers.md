# Story 020: Test Infrastructure Helpers

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: N/A (test tooling)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A
**ADR Decision Summary**: Test helpers must be DI-compatible (untyped) and must not reference real autoloads — pure in-memory stubs that work headlessly in GUT.

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] (Story-level AC) `tests/helpers/enemy_director_test_harness.gd` — factory method `make_harness(run_seed: int, archetype: StringName) -> Dictionary` spins up EnemyDirector + minimal mock stubs for autoloads #5/#6/#7/#11/#12/#15/#28 (StatSystem, AbilitySystem, CombatResolver, LootDropSystem, WorkoutStateTracker, ParticleSystemWrapper, TelemetryManager). Returns dict with `{director, mocks}`.
- [ ] (Story-level AC) `tests/helpers/rng_determinism_helper.gd` — `compare_sequences(seq_a: Array[float], seq_b: Array[float]) -> Dictionary` comparing two RNG output sequences; returns `{match: bool, first_diff_idx: int, diff_count: int}`. Used by AC-12, AC-15 tests.
- [ ] (Story-level AC) `tests/helpers/enemy_signal_recorder.gd` — connects to all 3 EnemyDirector signals (`hit_resolved`, `enemy_killed`, `combat_metric_anomaly`); records `{timestamp_ms: int, payload: Variant}` tuples. Exposes: `get_hit_resolved_count() -> int`, `get_enemy_killed_count() -> int`, `get_anomaly_count() -> int`, `get_anomaly_by_reason(reason: StringName) -> Array`, `clear()`.
- [ ] (Story-level AC) `tests/helpers/archetype_resource_factory.gd` — `make_registry(archetypes: Array[StringName]) -> EnemyRegistry`: synthesizes `EnemyRegistry` + `WaveDescriptor` resources in-memory with configurable baseline values. Used by AC-17 tests to avoid file I/O dependency.
- [ ] (Story-level AC) `tests/helpers/mock_workout_state_tracker.gd` — implements `get_dominant_ability_class() -> int` (returns configurable value) + `set_progress: float` property + `get_current_set_progress() -> float` + `get_reps_completed() -> int` + `get_planned_reps() -> int`. Used by AC-18/20/21 deferred tests and Story 011/016 tests.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- All helpers extend `RefCounted` or plain GDScript (NOT `Node`). No scene tree dependency.
- All helpers are DI-compatible: no references to real autoloads (no `GameStateMachine`, no `AbilitySystem`, etc.). Provide stubs that match the untyped DI seam interface.
- `enemy_director_test_harness.gd`:
  - Creates fresh `EnemyDirector` instance (not autoload)
  - Injects mocks via untyped property assignment (per GDScript DI seam constraint)
  - Stubs: `MockGSM` (returns configurable `current_state`, `current_transition_id`), `MockAbilitySystem`, `MockStatSystem` (configurable `get_stat` return), `MockCombatResolver` (configurable `resolve_hit` return), `MockParticleSystem` (call spy), etc.
  - Call `director._ready()` after injection to initialize containers
- `enemy_signal_recorder.gd`: connect via `director.hit_resolved.connect(_on_hit_resolved)` etc. Store tuples with injected `now_ms` from harness clock.
- `archetype_resource_factory.gd`: construct `WaveDescriptor` resources programmatically (not loaded from disk); set all required fields to sensible defaults; allow override via named params.
- `mock_workout_state_tracker.gd`: simple class with public vars for all properties; no logic.
- Naming: all helpers prefixed with purpose to avoid collision with actual game classes.
- IMPORTANT: Write these helpers BEFORE implementing Stories 011-019 for maximum reuse. These are the foundation of the test suite.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: EnemyDirector class (helpers mock this, do not replace it)
- All Stories 011-019: Actual tests that USE these helpers

---

## QA Test Cases

These helpers have no direct test — validated indirectly when Stories 011-019 tests pass using them.

Self-check: each helper file should include a `static func _static_check()` method that runs a basic sanity assertion:
- `enemy_signal_recorder.gd._static_check()`: connect to dummy signal, fire it, assert count == 1, `clear()`, assert count == 0.
- `rng_determinism_helper.gd._static_check()`: compare `[1.0, 2.0, 3.0]` with `[1.0, 2.0, 3.0]` → `match=true, diff_count=0`. Compare with `[1.0, 2.5, 3.0]` → `match=false, first_diff_idx=1, diff_count=1`.
- `archetype_resource_factory.gd._static_check()`: `make_registry(["STRIKE"])` → registry has 1 archetype key, WaveDescriptor has `move_speed > 0`.

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: N/A — helpers are validated indirectly when Stories 011-019 tests pass
**Status**: [x] Created; 5 helpers + GUT 8/8 validation PASS; full suite 250/250 (Godot 4.6.3, 2026-06-01)

---

## Completion Notes

**Completed**: 2026-06-01 (retroactive consolidation — Stories 011-019 were built with inline fakes; these helpers formalise the reusable infrastructure with `_static_check()` self-tests)
**Criteria**: 5/5 helpers delivered
**Implementation**: `tests/helpers/` — `rng_determinism_helper.gd` (compare_sequences), `enemy_signal_recorder.gd` (3-signal recorder + by-reason query), `archetype_resource_factory.gd` (in-memory EnemyRegistry/WaveDescriptor, baselines mirror shipped .tres), `mock_workout_state_tracker.gd` (configurable WST stub), `enemy_director_test_harness.gd` (fresh EnemyDirector instance + 5 mock seams via load-by-path). All RefCounted, no scene-tree/autoload coupling, no class_name (preloaded by path).
**Key fix**: WaveDescriptor.max_hp/defense are typed Array[int] — factory uses Array.assign() to convert.
**Test Evidence**: test_helpers_static_check.gd (8 — each helper's _static_check + behaviour spot-checks).

---

## Dependencies

- Depends on: Story 001 (EnemyDirector class must exist to mock)
- Unlocks: Accelerates implementation of Stories 011-019 (provide pre-built mock infrastructure)
