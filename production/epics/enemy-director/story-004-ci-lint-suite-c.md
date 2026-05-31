# Story 004: CI Lint Suite C — Forbidden Patterns / Move Cap / Dodge Invariant

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-004, TR-enemy-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 structural
**ADR Decision Summary**: ADR-0001 structural decisions lock Camera2D mutation, GPUParticles2D instantiation, and particle concurrency patterns; CI scripts enforce these at commit time.

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-05 [Logic|BLOCKING|static]: Extend `tools/ci/check_camera_callers.gd` + `check_particle_callers.gd` + `check_screen_effects_callers.gd` (already exist) to also scan `enemy_director.gd` — no direct `Camera2D.position` / `Camera2D.zoom` / `Camera2D.offset` / `GPUParticles2D.emitting = true` mutation. Fixture: extended with EnemyDirector violation case.
- [ ] AC-26 [Logic|BLOCKING|static]: Extend `tools/ci/check_particle_callers.gd` — reject `GPUParticles2D.new()` or direct `.tscn` particle instantiate in `enemy_director.gd`; all particle dispatch via `ParticleSystemWrapper.play(preset, position, caller_mult)`. Fixture: extended positive case.
- [ ] AC-31 [Logic|BLOCKING|static]: `tools/ci/check_enemy_template_move_cap.gd` — scan `assets/data/EnemyRegistry.tres`; verify all `_template_move_speed` ≤ `ENEMY_MOVE_CAP=420` (STRIKE=120 / CONTROL=90 / MOBILITY=280 all pass). Fixture.
- [ ] AC-32 [Logic|BLOCKING|static]: `tools/ci/check_dodge_amplitude_invariant.gd` — verify `DODGE_AMPLITUDE_PX=30`; assert `30×2=60 < MELEE_RANGE=80` (INV-8 post-fix). Fixture.
- [ ] (Story-level AC) `tools/ci/check_boss_anchor_state_transitions.gd` — whitelist legal BossAnchorState transitions: `IDLE→PRE_SPAWN→COMMIT_PENDING→COMMITTED→ENGAGED` + rollback paths (`PRE_SPAWN→IDLE`). Reject undeclared transitions. Fixture.
- [ ] (Story-level AC) `tools/ci/check_particle_concurrency_cap.gd` — verify `MAX_CONCURRENT_PARTICLE_EMITTERS` declared as `const` (not `var`) in `enemy_director.gd`. Fixture: `var MAX_CONCURRENT_PARTICLE_EMITTERS` → exit 1; `const MAX_CONCURRENT_PARTICLE_EMITTERS` → exit 0.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `check_camera_callers.gd` already exists from ADR-0001 implementation; extend its scan list to include `src/autoload/enemy_director.gd`.
- `check_particle_callers.gd` already exists; extend to reject `GPUParticles2D.new()` and direct instantiation patterns in enemy_director.gd.
- `check_screen_effects_callers.gd` already exists; extend similarly.
- `check_enemy_template_move_cap.gd`: parse `EnemyRegistry.tres` as text; extract `_template_move_speed` values; assert each ≤ 420. Static assertion: `STRIKE=120 ✓, CONTROL=90 ✓, MOBILITY=280 ✓`.
- `check_dodge_amplitude_invariant.gd`: scan `enemy_director.gd` for `DODGE_AMPLITUDE_PX` const; extract value; assert `value * 2 < MELEE_RANGE`. MELEE_RANGE=80 must also be readable (const in file or injected as known value).
- `check_boss_anchor_state_transitions.gd`: whitelist as set; scan for any `_boss_anchor_state =` assignment with a value not reachable from legal transition table.
- `check_particle_concurrency_cap.gd`: regex `const\s+MAX_CONCURRENT_PARTICLE_EMITTERS` vs `var\s+MAX_CONCURRENT_PARTICLE_EMITTERS`.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: CI Lint Suite A (RNG / chokepoint / stat)
- Story 003: CI Lint Suite B (boot order / signal lifecycle / state locality)
- Story 010: EnemyRegistry.tres data file (must exist before AC-31 can run)

---

## QA Test Cases

**AC-05**: Given: fixture `enemy_director.gd` containing `$Camera2D.position = Vector2(0,0)`. When: extended `check_camera_callers.gd` runs. Then: exit code 1. Given: no camera mutation. Then: exit code 0.

**AC-26**: Given: fixture with `GPUParticles2D.new()` in enemy_director. When: `check_particle_callers.gd` runs. Then: exit code 1. Given: `ParticleSystemWrapper.play(...)` only. Then: exit code 0.

**AC-31**: Given: `EnemyRegistry.tres` fixture with `_template_move_speed = 500`. When: `check_enemy_template_move_cap.gd` runs. Then: exit code 1. Given: all speeds ≤ 420. Then: exit code 0.

**AC-32**: Given: `DODGE_AMPLITUDE_PX=50` (50×2=100 > 80). When: `check_dodge_amplitude_invariant.gd` runs. Then: exit code 1. Given: `DODGE_AMPLITUDE_PX=30` (30×2=60 < 80). Then: exit code 0.

**Boss anchor transitions**: Given: code assigning `_boss_anchor_state = BossAnchorState.ENGAGED` from `IDLE` (illegal jump). When: lint runs. Then: exit code 1.

**Particle cap**: Given: `var MAX_CONCURRENT_PARTICLE_EMITTERS = 8`. When: lint runs. Then: exit code 1. Given: `const MAX_CONCURRENT_PARTICLE_EMITTERS = 8`. Then: exit code 0.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 4+ CI scripts in `tools/ci/` (extensions + new scripts) + fixture files in `tests/ci_fixtures/`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (EnemyDirector source must exist), Story 010 (EnemyRegistry.tres must exist for AC-31)
- Unlocks: All lint-verified stories (018 AOE pipeline, 015 particle throttle)
