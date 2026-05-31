# Story 004: CI Lint Suite C — Forbidden Patterns / Move Cap / Dodge Invariant

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31

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

- [x] AC-05 [Logic|BLOCKING|static]: Extend `tools/ci/check_camera_callers.gd` + `check_particle_callers.gd` + `check_screen_effects_callers.gd` (already exist) to also scan `enemy_director.gd` — no direct `Camera2D.position` / `Camera2D.zoom` / `Camera2D.offset` / `GPUParticles2D.emitting = true` mutation. Fixture: extended with EnemyDirector violation case.
- [x] AC-26 [Logic|BLOCKING|static]: Extend `tools/ci/check_particle_callers.gd` — reject `GPUParticles2D.new()` or direct `.tscn` particle instantiate in `enemy_director.gd`; all particle dispatch via `ParticleSystemWrapper.play(preset, position, caller_mult)`. Fixture: extended positive case.
- [x] AC-31 [Logic|BLOCKING|static]: `tools/ci/check_enemy_template_move_cap.gd` — scan `assets/data/EnemyRegistry.tres`; verify all `_template_move_speed` ≤ `ENEMY_MOVE_CAP=420` (STRIKE=120 / CONTROL=90 / MOBILITY=280 all pass). **Forward-compat exit-2**: `EnemyRegistry.tres` not yet created (Story 010 scope) → script exits 2 (graceful skip, not a CI fail). Tests use inline text fixture (same approach as AC-04 simulated project.godot). Fixture pos: `_template_move_speed = 500` → exit 1; fixture neg: all ≤ 420 → exit 0; absent file → exit 2.
- [x] AC-32 [Logic|BLOCKING|static]: `tools/ci/check_dodge_amplitude_invariant.gd` — verify `DODGE_AMPLITUDE_PX=30` declared as `const` in `enemy_director.gd`; assert `30×2=60 < MELEE_RANGE=80` (INV-8 post-fix). **Forward-compat exit-2**: `DODGE_AMPLITUDE_PX` const not yet declared (Story 015 scope) → script exits 2 (const not found, graceful skip). Tests use fixture with const declared. Fixture pos: `DODGE_AMPLITUDE_PX=50` (50×2=100 > 80) → exit 1; neg: `DODGE_AMPLITUDE_PX=30` → exit 0; const absent → exit 2.
- [x] (Story-level AC) `tools/ci/check_boss_anchor_state_transitions.gd` — whitelist legal BossAnchorState transitions: `IDLE→PRE_SPAWN→COMMIT_PENDING→COMMITTED→ENGAGED` + rollback paths (`PRE_SPAWN→IDLE`, `COMMIT_PENDING→IDLE`, `any→IDLE via workout_abandoned`). Reject any `_boss_anchor_state = BossAnchorState.<value>` assignment where the transition from prior state is not in the whitelist. Fixture.
- [x] (Story-level AC) `tools/ci/check_particle_concurrency_cap.gd` — verify `MAX_CONCURRENT_PARTICLE_EMITTERS` declared as `const` (not `var`) in `enemy_director.gd`. **Forward-compat exit-2**: const not yet declared (Story 015 scope) → script exits 2 (not found, graceful skip). Fixture: `var MAX_CONCURRENT_PARTICLE_EMITTERS` → exit 1; `const MAX_CONCURRENT_PARTICLE_EMITTERS` → exit 0; const absent → exit 2.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `check_camera_callers.gd` / `check_particle_callers.gd` / `check_screen_effects_callers.gd` all exist **as STUBS** (`push_warning + quit(0)`) — dev must **fully implement** the detection regex from scratch, not merely add enemy_director.gd to a scan list. The stubs need complete implementation: regex-based source scan, violation reporting (file:line:col), exit 0/1/2 semantics. This is the bulk of Story 004 work.
- `check_enemy_template_move_cap.gd`: parse `assets/data/EnemyRegistry.tres` as text; extract `_template_move_speed` values; assert each ≤ 420. Static assertion: `STRIKE=120 ✓, CONTROL=90 ✓, MOBILITY=280 ✓`. NOTE: `EnemyRegistry.tres` is created by Story 010 (Status: Ready). Until Story 010 ships, script gracefully exits 2 (target missing). For tests, use a text fixture containing a simulated `.tres` block (same approach as AC-04 using simulated project.godot text). Fixture: `tests/fixtures/enemy_director_move_cap_violation.gd` (violation: `_template_move_speed = 500`) + `enemy_director_move_cap_clean.gd` (all ≤ 420).
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

**AC-31**: Given: inline `.tres` text fixture with `_template_move_speed = 500`. When: `check_enemy_template_move_cap.gd` runs. Then: exit code 1. Given: all speeds ≤ 420. Then: exit code 0. Given: target file path not found. Then: exit code 2 (graceful skip — Story 010 not yet shipped).

**AC-32**: Given: fixture with `const DODGE_AMPLITUDE_PX = 50` (50×2=100 > 80). When: `check_dodge_amplitude_invariant.gd` runs. Then: exit code 1. Given: `const DODGE_AMPLITUDE_PX = 30` (30×2=60 < 80). Then: exit code 0. Given: const absent from file (Story 015 not yet done). Then: exit code 2.

**Boss anchor transitions**: Given: code assigning `_boss_anchor_state = BossAnchorState.ENGAGED` from `IDLE` (illegal jump). When: lint runs. Then: exit code 1.

**Particle cap**: Given: fixture with `var MAX_CONCURRENT_PARTICLE_EMITTERS = 8`. When: lint runs. Then: exit code 1. Given: `const MAX_CONCURRENT_PARTICLE_EMITTERS = 8`. Then: exit code 0. Given: const absent from file. Then: exit code 2 (Story 015 not yet done).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 4+ CI scripts in `tools/ci/` (extensions + new scripts) + fixture files in `tests/fixtures/` + test functions added to `tests/static/test_enemy_director_ci_lint.gd`
**Status**: [x] 7 CI scripts (3 stubs replaced + 4 new) + 10 fixtures created; test file extended (+20 tests → 59 total); GUT 59/59 PASS (Godot 4.6.2, 2026-05-31)

---

## Completion Notes

**Completed**: 2026-05-31
**Criteria**: 6/6 passing
**Forward-compat design**: AC-31 (EnemyRegistry.tres / Story 010), AC-32 + particle_cap (const / Story 015) all exit 2 (graceful skip) when target/const absent — NOT exit 1. Real-source confirmation tests assert absence so the exit-2 path is locked until those stories ship.
**Deviations / fixes during review**:
- MAJOR-1 FIXED: 3 full-src scan scripts (camera/particle/screen_effects) now strip trailing inline comments before matching (via `_strip_trailing_comment` helper, string-literal-aware) — prevents future false-positive when a dev writes an inline comment mentioning a forbidden token.
- MAJOR-2 FIXED: test `.emitting` pattern aligned to production's anchored `GPUParticles2D[^\n]*\.emitting\s*=` (was naked `.emitting=true` — protected wrong pattern).
- ADVISORY (deferred): boss-transition has no dedicated clean fixture (relies on real-source IDLE-init assertion); inline-regex non-subprocess precedent (same as Story 002/003).
**Test Evidence**: `tests/static/test_enemy_director_ci_lint.gd` — 59 tests (20 Story 004 + 39 prior), zero regression. Godot 4.6.2 local GUT.
**Code Review**: Complete — GDScript specialist ADEQUATE (0 CRITICAL; 2 MAJOR fixed); qa-tester TESTABLE (6/6 two-sided + exit-2 forward-compat).

---

## Dependencies

- Depends on: Story 001 (EnemyDirector source must exist), Story 010 (EnemyRegistry.tres must exist for AC-31)
- Unlocks: All lint-verified stories (018 AOE pipeline, 015 particle throttle)
