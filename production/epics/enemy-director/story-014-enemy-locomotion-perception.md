# Story 014: Enemy Locomotion + 4Hz Batch Perception (Rule 18 + Formula 6)

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-019, TR-enemy-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 structural + ADR-0006
**ADR Decision Summary**: ADR-0001 mandates draw-call and CPU budget caps; 4Hz batch perception is the budget-compliance strategy for avatar distance reads; ADR-0006 mandates deterministic locomotion via injectable delta.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-30 [Logic|BLOCKING|unit]: Formula 6 worked example: `_template_move_speed=120, direction=+1, delta=1/60, velocity.x_old=0`. Then: `move_toward(0, 120, 1200×(1/60))=20`; `clamp(20, -420, +420)=20`; `velocity.x_new=20`; `velocity.y=0`.
- [ ] (Story-level AC) MOBILITY dodge: given MOBILITY enemy + `_rng_factory.create_sub(transition_id, "dodge_{instance_id}")`. When re-roll every `dodge_interval_sec=1.5s`. Then: `dodge_offset_x ∈ [-30.0, +30.0]` (DODGE_AMPLITUDE_PX=30 post INV-8 fix); deterministic per (transition_id, instance_id); `30×2=60 < MELEE_RANGE=80` ✓ (INV-8). Same seed → same sequence across reruns.
- [ ] (Story-level AC) 4Hz batch perception: given 8 active enemies. When `_perception_tick_accumulator >= 0.25s`. Then: EnemyDirector reads avatar position ONCE; updates all 8 enemy `_cached_avatar_distance` fields. Budget: single avatar position read per 250ms (not 8 reads per frame).

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

**Formula 6 — Per-enemy locomotion** (runs in enemy node `_physics_process(delta)`):
- `var accel = _template_move_speed * 10.0` (acceleration = 10× max speed)
- `velocity.x = move_toward(velocity.x, _template_move_speed * direction, accel * delta)`
- `velocity.x = clamp(velocity.x, -ENEMY_MOVE_CAP, ENEMY_MOVE_CAP)` (cap = 420)
- `velocity.y = 0.0` (2D side-scroller — no vertical locomotion for basic enemies)
- `move_and_slide()` for collision resolution
- Only run locomotion when `_ai_state == PURSUING` or `_ai_state == ATTACKING`

**MOBILITY dodge:**
- `var dodge_rng = _rng_factory.create_sub(transition_id, "dodge_%d" % instance_id)`
- Every `dodge_interval_sec=1.5s`, re-roll: `dodge_offset_x = dodge_rng.randf_range(-DODGE_AMPLITUDE_PX, DODGE_AMPLITUDE_PX)`
- Apply: `global_position.x += dodge_offset_x`
- `DODGE_AMPLITUDE_PX = 30` (const) — CI lint Story 004 AC-32 enforces
- Only applies when archetype == MOBILITY AND `_ai_state == PURSUING`

**4Hz batch perception** (EnemyDirector `_physics_process(delta)`):
- `_perception_tick_accumulator += delta`
- When `>= 0.25s`: read avatar `global_position` ONCE; iterate all enemies in `_enemy_state_pool`; call `enemy_node.set_avatar_distance(avatar_pos.distance_to(enemy_node.global_position))` for each; reset accumulator.
- `MAX_FRAME_DELTA = 0.1s` clamp: `delta = min(delta, 0.1)` — prevents physics explosion on long frames (shared constant with #6/#7).

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 006: RNGFactory `create_sub()` for dodge RNG
- Story 013: AI state machine that gates locomotion (PURSUING required)
- Story 012: Enemy spawn (nodes exist before locomotion runs)
- Story 015: Particle throttle (particle budget separate from locomotion)

---

## QA Test Cases

**AC-30 Formula 6**: Given: mock enemy with `_template_move_speed=120`, `velocity.x=0`, `direction=+1`, `delta=1.0/60.0`. When: apply Formula 6. Then: `velocity.x == 20.0` (move_toward(0, 120, 1200/60=20) == 20); `clamp(20, -420, 420) == 20`. Edge: `velocity.x=500` (above cap), `direction=+1` → `clamp(move_toward(500, 120, 20), -420, 420) == 420`... wait, deceleration → `move_toward(500, 120, 20) == 480`; `clamp(480, -420, 420) == 420`.

**MOBILITY dodge**: Given: MOBILITY enemy, `transition_id="TX-mob-001"`, `instance_id=42`. Compute `dodge_rng = create_sub("TX-mob-001", "dodge_42")`. When: advance timer 1.5s, re-roll dodge offset. Then: `dodge_offset_x` in `[-30.0, 30.0]`. Repeat with fresh factory same seed → same offset value (deterministic). Assert `DODGE_AMPLITUDE_PX * 2 = 60 < MELEE_RANGE = 80` (static assertion INV-8).

**4Hz perception**: Given: 8 mock enemy nodes in `_enemy_state_pool`; mock avatar at position (100, 0). When: accumulate delta until `>= 0.25s` (4 ticks of 1/16s). Then: avatar position read spy called exactly 1 time; all 8 enemy `_cached_avatar_distance` values updated; no per-enemy avatar reads.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/enemy_director/test_locomotion_formula.gd`
- `tests/unit/enemy_director/test_mobility_dodge.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 006 (RNGFactory sub-RNG for dodge), 013 (AI state gates locomotion)
- Unlocks: Story 018 (pipeline complete — locomotion + combat integrated)
