# Story 017: Boss Anchor Commit + Entry Cascade (Rule 13 part 2)

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-014, TR-enemy-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 + ADR-0001 structural
**ADR Decision Summary**: ADR-0006 mandates that all cascade steps run in the same frame with defined sequential order; ADR-0001 structural mandates all Camera/ScreenEffects/Particle calls go through their respective autoloads, never direct node mutation.

**Engine**: Godot 4.6 | **Risk**: HIGH

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-19 [Logic|BLOCKING|unit]: Given BOSS `hit_result.is_kill == true`. When EnemyDirector handles hit. Then: `enemy_killed` emitted SAME FRAME (no `call_deferred`); non-boss enemies in pool NOT force-despawned (narrative continuity — Rule 13 boundary with #16).
- [ ] AC-33 [Integration|BLOCKING|integration]: Given `_boss_anchor_state == COMMITTED`. When commit frame triggers (`workout_completed` from #1 GSM). Then sequential dispatch in EXACT order, all in same `_physics_process` frame:
  1. `boss.visible = true`
  2. `boss.ai_state = EnemyAIState.ENGAGE` (or equivalent engage trigger)
  3. `CameraSystem.focal_request(boss_target, 0.6s, "quart_ease_out")`
  4. `ScreenEffects.shake(0.4, 0.08s)`
  5. `ParticleSystem.play("BOSS_ENTRY", boss_pos, 1.2)`
  All 5 in exact order. `ParticleSystem` caller_mult=1.2 (boss spectacle > ambient 0.8).
- [ ] [Note: AC-20 deferred → Story 023 BLOCKED pending #9 WST]

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `_on_state_changed` handles GSM `to == "BossEncounter"` → trigger commit if `_boss_anchor_state == COMMIT_PENDING`.
- State transition before cascade: `_boss_anchor_state = COMMITTED`.
- Boss kill handling (`_apply_hit_result` for boss enemy):
  - `enemy_killed` emit is SAME FRAME — use direct emit, NOT `call_deferred`.
  - Non-boss enemies in pool preserved (no `queue_free()` on non-boss nodes).
  - Boss `_on_enemy_despawned` cleans pool (Story 012 mechanism).
- Cascade step order enforced by sequential GDScript lines (no `await`, no process_frame defers between steps).
- CameraSystem / ScreenEffects / ParticleSystem DI seams: inject via untyped properties for spy injection in integration tests.
- After COMMITTED entry cascade: `_boss_anchor_state = ENGAGED`.
- `COMMIT_PENDING` state set in `pre_spawn_boss()` after boss node added to scene (Story 016 sets `PRE_SPAWN` → external event or timer moves to `COMMIT_PENDING`).
- Mini-boss vs standard differentiation: read `_active_boss_is_mini: bool` flag set during `pre_spawn_boss()`.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004: CI lint verifying legal BossAnchorState transitions (including COMMITTED→ENGAGED)
- Story 015: Particle throttle that may modify `_caller_mult` (boss override at 1.2 bypasses ambient throttle)
- Story 016: PRE_SPAWN + rollback (part 1 of boss anchor)
- Story 019: enemy_killed signal chain + idempotency (boss kill follows same dedupe path)
- Story 023: BLOCKED — boss anchor latency gate (AC-20 deferred)

---

## QA Test Cases

**AC-19 boss death**: Given: mock boss enemy in `_enemy_state_pool`; 3 non-boss enemies also in pool. When: `_apply_hit_result(boss_instance_id, HitResult{is_kill: true})`. Then: `enemy_killed` signal spy called in same call stack frame (not deferred); non-boss entries still present in `_enemy_state_pool`; boss entry removed.

**AC-33 entry cascade order**: Given: inject mock CameraSystem spy + mock ScreenEffects spy + mock ParticleSystem spy. Set `_boss_anchor_state = COMMIT_PENDING`. When: `_on_state_changed({to: "BossEncounter"})`. Then:
1. Boss `visible` set to `true` before any spy calls
2. Boss `ai_state` set to ENGAGE before any spy calls
3. CameraSystem spy call #1: `focal_request(boss_target, 0.6, "quart_ease_out")`
4. ScreenEffects spy call #1: `shake(0.4, 0.08)`
5. ParticleSystem spy call #1: `play("BOSS_ENTRY", boss_pos, 1.2)`

Assert call order using spy call index: Camera index < ScreenEffects index < Particle index. Assert all in same `_physics_process` tick (no frame gap).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/enemy_director/test_boss_death_signal.gd`
- `tests/integration/enemy_director/test_boss_entry_cascade.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 005 (signals), 015 (particle dispatch system), 016 (boss pre-spawn state)
- Unlocks: Story 019 (enemy_killed chain verified end-to-end), epic integration tests
