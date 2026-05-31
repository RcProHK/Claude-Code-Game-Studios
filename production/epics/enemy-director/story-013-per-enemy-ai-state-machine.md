# Story 013: Per-enemy AI State Machine 6 States (Rule 17)

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 + ADR-0007 (EnemyAIState enum naming)
**ADR Decision Summary**: ADR-0006 mandates transition atomicity for all state machines; ADR-0007 Family A mandates ordinal 0 = safe boot default for outcome/state enums (SPAWNING=0).

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-27 [Logic|BLOCKING|unit]: Enemy in IDLE state + avatar X-distance ≤ `PERCEPTION_RANGE=600px` (cached from 4Hz batch per Rule 18). Then: `_state` transitions `IDLE→PURSUING`. Reverse: X-distance > `LEASH_RANGE=900px` → `PURSUING→IDLE` (hysteresis; 900 > 600 prevents flicker).
- [ ] AC-28 [Logic|BLOCKING|unit]: Enemy in any non-DYING state + `hit_resolved` payload `damage_tier==HEAVY` AND `target_id==self.get_instance_id()`. Then: STAGGERED with duration `0.15s`. CRITICAL tier → `0.30s` (`STAGGER_DURATION_BY_TIER`). No re-trigger of STAGGER while already STAGGERED. (EC-35)
- [ ] AC-29 [Logic|BLOCKING|unit]: Enemy in ATTACKING state mid-animation + `hit_resolved` `is_kill==true`. Then: transition immediately to DYING (priority over ATTACKING completion); attack animation interrupted; no `ability_cast` emitted. (EC-36)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `EnemyAIState` enum declared on `EnemyDirector` (or in separate file imported): `enum EnemyAIState { SPAWNING=0, IDLE=1, PURSUING=2, ATTACKING=3, STAGGERED=4, DYING=5 }` — ADR-0007 Family A (0 = safe boot default = SPAWNING).
- AI state lives on EACH enemy node instance (not centralized in EnemyDirector). Enemy script: `var _ai_state: EnemyDirector.EnemyAIState = EnemyDirector.EnemyAIState.SPAWNING`.
- `_cached_avatar_distance: float` updated externally by EnemyDirector 4Hz batch perception (Story 014). Enemy node exposes setter `set_avatar_distance(d: float)`.
- Perception transitions (checked in enemy `_physics_process`):
  - If `_ai_state == IDLE` AND `_cached_avatar_distance <= PERCEPTION_RANGE`: → PURSUING
  - If `_ai_state == PURSUING` AND `_cached_avatar_distance > LEASH_RANGE`: → IDLE
- STAGGER transitions (event-driven via signal):
  - Subscribe to `EnemyDirector.hit_resolved` in `_ready()`; filter by `target_instance_id == get_instance_id()`
  - If `damage_tier == HEAVY` AND `_ai_state != DYING`: → STAGGERED; create timer `0.15s`; on timeout → return to PURSUING
  - If `damage_tier == CRITICAL` AND `_ai_state != DYING`: → STAGGERED; timer `0.30s`
  - If already STAGGERED: ignore incoming stagger (no re-trigger)
- DYING priority (event-driven):
  - On `hit_resolved` with `is_kill == true` AND `target_instance_id == self`: → DYING immediately; interrupt current animation; block any further signal processing
  - Use `CONNECT_ONE_SHOT` on kill signal to prevent double-processing
- `STAGGER_DURATION_BY_TIER: Dictionary = { DamageTier.HEAVY: 0.15, DamageTier.CRITICAL: 0.30 }`
- `PERCEPTION_RANGE = 600.0`, `LEASH_RANGE = 900.0` — consts on EnemyDirector.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 012: Enemy spawn (initial AI state = SPAWNING from pool entry)
- Story 014: 4Hz batch perception that updates `_cached_avatar_distance`; locomotion physics

---

## QA Test Cases

**AC-27 perception**: Given: enemy mock with `_ai_state=IDLE`, `_cached_avatar_distance=550`. When: `_physics_process(delta)`. Then: `_ai_state == PURSUING`. Given: set distance to 950. Then: `_ai_state == IDLE`. Given: set distance to 550 again. Then: `_ai_state == PURSUING` (hysteresis working — no oscillation at 600 boundary).

**AC-28 stagger HEAVY**: Given: enemy in PURSUING state. When: `hit_resolved` signal fires with `damage_tier=HEAVY`, `target_instance_id=enemy.get_instance_id()`. Then: `_ai_state == STAGGERED`. After 0.15s timer: `_ai_state == PURSUING`. Edge: second HEAVY hit while STAGGERED → state stays STAGGERED (no re-trigger); timer NOT reset.

**AC-28 stagger CRITICAL**: Same as above but `damage_tier=CRITICAL` → timer = 0.30s.

**AC-29 dying priority**: Given: enemy in ATTACKING state. When: `hit_resolved` with `is_kill=true`, `target_instance_id=enemy.get_instance_id()`. Then: `_ai_state == DYING` immediately; animation spy received interrupt call; no `ability_cast` signal emitted in that frame.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/enemy_director/test_enemy_ai_perception.gd`
- `tests/unit/enemy_director/test_enemy_ai_stagger.gd`
- `tests/unit/enemy_director/test_enemy_ai_dying_priority.gd`
**Status**: [x] Created; GUT 16/16 (story) + 125/125 (suite) PASS (Godot 4.6.3, 2026-06-01)

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3 passing (AC-27 perception+hysteresis, AC-28 stagger EC-35, AC-29 dying priority EC-36)
**Implementation**: `src/ai/enemy.gd` (`class_name Enemy extends Node2D`) — per-node AI state machine: SPAWNING→IDLE settle; IDLE↔PURSUING with PERCEPTION_RANGE/LEASH_RANGE hysteresis; STAGGERED (HEAVY 0.15s / CRITICAL 0.30s, no re-trigger) via EnemyDirector.hit_resolved filtered by target_id; DYING priority on is_kill (terminal, interrupts animation). New EnemyDirector consts PERCEPTION_RANGE/LEASH_RANGE/STAGGER_DURATION_BY_TIER.
**Key reconciliation**: payload field is `target_id` (not the story's `target_instance_id`). animation_interrupted flag + virtual `_interrupt_animation()` for AC-29 observability (Story 014+ overrides for real AnimationPlayer).
**Test Evidence**: test_enemy_ai_perception.gd (5) + test_enemy_ai_stagger.gd (6) + test_enemy_ai_dying_priority.gd (5).
**Code Review**: deferred to batch review (autonomous epic completion run).

---

## Dependencies

- Depends on: Stories 001 (EnemyAIState enum + EnemyDirector signals), 005 (hit_resolved signal), 012 (enemy spawn — nodes exist)
- Unlocks: Story 014 (locomotion needs AI state to gate movement)
