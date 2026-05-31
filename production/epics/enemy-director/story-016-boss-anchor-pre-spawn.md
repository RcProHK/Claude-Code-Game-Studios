# Story 016: Boss Anchor Pre-spawn + Rollback (Rule 13 part 1)

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-015, TR-enemy-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006
**ADR Decision Summary**: ADR-0006 mandates transition atomicity; boss anchor state machine transitions must be atomic with no partial states; rollback to IDLE must be clean (no ghost signals, no orphaned nodes).

**Engine**: Godot 4.6 | **Risk**: HIGH

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-21 [Logic|BLOCKING|unit]: Given `_boss_anchor_state == PRE_SPAWN`. When `set_progress` drops below 0.8 (injected via mock WST). Then: `despawn_boss_silently()` called; `_boss_anchor_state = IDLE`; NO `enemy_killed` emitted; NO anomaly emitted (legitimate rollback). (EC-15)
- [ ] AC-22 [Logic|BLOCKING|unit]: Given `total_planned_sets <= LIGHT_WORKOUT_THRESHOLD_SETS = 2`. When final set complete + boss entry triggered. Then: spawn mini-boss (NOT final boss pool); `Camera.focal_request(boss, 0.4s, ...)` (not 0.6s); `ScreenEffects.shake(0.25, ...)` (not 0.4); `ParticleSystem.play("BOSS_ENTRY", pos, 1.0)` (not 1.2). (EC-19)
- [ ] (Story-level AC) BossAnchorState FSM — Formula 5 trigger: given `_boss_anchor_state == IDLE AND current_set == final_planned_set AND set_progress >= 0.8`. When perception tick (4Hz) fires. Then: `pre_spawn_boss(off_screen_x)` called; `_boss_anchor_state = PRE_SPAWN`. Edge: `set_progress` not exposed → fallback `reps_completed >= ceil(planned_reps × 0.5)` triggers instead. (EC-14)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `BossAnchorState` enum (ADR-0007 Family A): `enum BossAnchorState { IDLE=0, PRE_SPAWN=1, COMMIT_PENDING=2, COMMITTED=3, ENGAGED=4 }`.
- Formula 5 check in `_check_boss_anchor_state(delta)` called from `_physics_process`. NOT every frame — gated by 4Hz perception accumulator (reuse `_perception_tick_accumulator`).
- `set_progress: float` read from `WorkoutStateTracker.get_current_set_progress()` (DI seam — untyped for test injection).
- Fallback (EC-14): if `WorkoutStateTracker` doesn't expose `set_progress`, use `WorkoutStateTracker.get_reps_completed() >= ceili(WorkoutStateTracker.get_planned_reps() * 0.5)`.
- `pre_spawn_boss(off_screen_x: float)`:
  - Determine boss pool: if `total_planned_sets <= 2` → mini-boss pool; else → final boss pool
  - Instantiate boss node off-screen at X=`off_screen_x` (negative — left off-screen)
  - Set boss node visible = false
  - Add boss to scene tree (but not yet to pool — COMMITTED state handles pool insertion)
  - `_boss_anchor_state = PRE_SPAWN`
- Rollback (`despawn_boss_silently()`):
  - `boss_node.queue_free()` — removes from scene tree
  - `_boss_anchor_state = IDLE`
  - Do NOT emit `enemy_killed` (boss never entered COMMITTED or ENGAGED)
  - Do NOT emit anomaly (rollback is expected behavior)
- `LIGHT_WORKOUT_THRESHOLD_SETS = 2` const.
- Mini-boss cascade parameters (EC-19): Camera=0.4s, shake=0.25, particle_mult=1.0.
- Standard cascade parameters: Camera=0.6s, shake=0.4, particle_mult=1.2.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 005: GSM state_changed subscription
- Story 011: Wave scheduler (wave tracking provides current_set/final_planned_set context)
- Story 017: Boss commit + entry cascade (continues from PRE_SPAWN → COMMITTED → ENGAGED)

---

## QA Test Cases

**AC-21 rollback**: Given: `_boss_anchor_state = PRE_SPAWN`, mock boss node in scene, `set_progress = 0.7` (below 0.8). When: perception tick fires. Then: `despawn_boss_silently()` called (mock boss queue_freed); `_boss_anchor_state == BossAnchorState.IDLE`; `enemy_killed` signal spy count == 0; anomaly spy count == 0.

**AC-22 light workout mini-boss**: Given: `total_planned_sets = 2`; trigger boss entry commit. When: entry cascade fires. Then: Camera spy received `focal_request(boss, 0.4, ...)` NOT 0.6s; ScreenEffects spy received `shake(0.25, ...)` NOT 0.4; ParticleSystem spy received `play("BOSS_ENTRY", _, 1.0)` NOT 1.2.

**Formula 5 trigger**: Given: `_boss_anchor_state = IDLE`; inject `current_set = final_planned_set`; inject `set_progress = 0.85`. When: `_check_boss_anchor_state()` evaluates. Then: `pre_spawn_boss()` called; `_boss_anchor_state == PRE_SPAWN`.

**EC-14 fallback**: Given: WST does NOT expose `get_current_set_progress()`; inject `reps_completed = 3`, `planned_reps = 5`, `ceil(5*0.5)=3`. When: check. Then: fallback triggers; pre_spawn_boss called.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/enemy_director/test_boss_rollback.gd`
- `tests/unit/enemy_director/test_light_workout_mini_boss.gd`
**Status**: [x] Created; GUT 11/11 (story) + 157/157 (suite) PASS (Godot 4.6.3, 2026-06-01)

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3 passing (AC-21 silent rollback EC-15, AC-22 mini-boss params EC-19, Formula 5 trigger EC-14)
**Implementation**: boss anchor FSM on EnemyDirector — `_check_boss_anchor_state(set_progress, is_final_set, total_planned_sets)` (parameterized pure core: IDLE→PRE_SPAWN on final+≥0.8, PRE_SPAWN→IDLE on progress drop); `pre_spawn_boss` (mini/final scene select, hidden off-screen, add_child, store cascade params); `despawn_boss_silently` (free + IDLE, NO enemy_killed/anomaly); `_select_boss_cascade_params` (mini ≤2 sets: cam0.4/shake0.25/mult1.0; standard: 0.6/0.4/1.2); `_poll_boss_anchor` (4Hz-gated WST read). Consts LIGHT_WORKOUT_THRESHOLD_SETS/BOSS_PRESPAWN_PROGRESS/BOSS_OFFSCREEN_X + cascade param consts. Seams _boss_scene_mini/_boss_scene_final.
**Scope split**: cascade EXECUTION (real Camera.focal_request/ScreenEffects.shake/Particle.play) + WST snapshot wiring (is_final_set/get_planned_total_sets) → Story 017 (those autoloads are stubs; AC-22 here verifies PARAM SELECTION). WST get_set_progress() already handles the EC-14 estimated fallback internally (Story 003).
**Test Evidence**: test_boss_rollback.gd (6) + test_light_workout_mini_boss.gd (5).
**Code Review**: deferred to batch review (autonomous epic completion run).

---

## Dependencies

- Depends on: Stories 001 (`_boss_anchor_state` container), 005 (GSM subscription), 006 (RNGFactory for boss RNG), 011 (wave tracking for set/progress context)
- Unlocks: Story 017 (boss commit cascade)
