# Story 012: Enemy Spawn + Lifecycle Pool Cleanup

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006
**ADR Decision Summary**: ADR-0006 mandates that spawn and despawn operations maintain pool state atomically; no partial states where a node exists in the scene tree but not in the pool (or vice versa).

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] (Story-level AC) Spawn flow: given wave cadence trigger + available slot in pool. When `_spawn_enemy(archetype, wave_seq)`. Then:
  - (a) sub-RNG `create_sub(transition_id, "wave_spawn_{wave_seq}")` used for position jitter
  - (b) `PackedScene` instantiated from `_spawn_pool[enemy_id]`
  - (c) `EnemyState{instance_id, enemy_id, hp=max_hp, max_hp, defense, faction}` inserted into `_enemy_state_pool`
  - (d) `enemy.tree_exited.connect(_on_enemy_despawned.bind(instance_id), CONNECT_ONE_SHOT)`
- [ ] (Story-level AC) Despawn flow: given enemy `tree_exited` fires. When `_on_enemy_despawned(instance_id)`. Then: `_enemy_state_pool.erase(instance_id)` AND `_killed_dedupe_set.erase(instance_id)` — both erased, no leak. (EC-38)
- [ ] (Story-level AC) Long-session: given spawn 100 enemies → kill all → despawn all. When pool and dedupe set inspected. Then: `_enemy_state_pool.is_empty() == true` AND `_killed_dedupe_set.is_empty() == true`. (EC-47)
- [ ] (Story-level AC) Given `HitResult.target_hp_after` received. When `_apply_hit_result(target, hit_result)`. Then: `_enemy_state_pool[instance_id].hp = hit_result.target_hp_after` updated immediately. (Rule 3 mutation)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `_spawn_enemy(archetype: StringName, wave_seq: int) -> void`:
  - `var sub_rng = _rng_factory.create_sub(GameStateMachine.current_transition_id, "wave_spawn_%d" % wave_seq)`
  - `var jitter_x = sub_rng.randf_range(-50.0, 50.0)` (spawn X offset)
  - Instantiate: `var enemy = _spawn_pool[archetype].instantiate()`
  - Set position to spawn point + jitter
  - `add_child(enemy)`
  - Create `EnemyState` with initial values from WaveDescriptor; `hp = max_hp`
  - `_enemy_state_pool[enemy.get_instance_id()] = state`
  - Connect one-shot despawn: `enemy.tree_exited.connect(_on_enemy_despawned.bind(enemy.get_instance_id()), CONNECT_ONE_SHOT)`
- `_on_enemy_despawned(instance_id: int) -> void`:
  - `_enemy_state_pool.erase(instance_id)`
  - `_killed_dedupe_set.erase(instance_id)` (clean dedupe set simultaneously)
- `_apply_hit_result(instance_id: int, hit_result: HitResult) -> void`:
  - Guard: `if not _enemy_state_pool.has(instance_id): return`
  - `_enemy_state_pool[instance_id].hp = hit_result.target_hp_after`
- Use `CONNECT_ONE_SHOT` flag so `tree_exited` auto-disconnects after first fire.
- Spawn position: off-screen right edge at varying Y; jitter from sub-RNG (deterministic).

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 006: RNGFactory `create_sub()` implementation
- Story 010: EnemyRegistry.tres data (archetype templates)
- Story 011: Wave cadence trigger that calls `_spawn_enemy()`
- Story 013: Per-enemy AI state machine (enemy node internals)
- Story 019: `_killed_dedupe_set` guard for `enemy_killed` signal (dedupe logic, not cleanup)

---

## QA Test Cases

**Spawn flow**: Given: mock PackedScene + mock RNGFactory + valid EnemyRegistry. When: `_spawn_enemy("STRIKE", 0)`. Then: `_enemy_state_pool.size() == 1`; `_enemy_state_pool[instance_id].hp == max_hp`; `_enemy_state_pool[instance_id].faction == 1` (ENEMY). Verify `tree_exited` connected (CONNECT_ONE_SHOT).

**Despawn flow**: Given: 1 enemy in pool with `instance_id=42`, `_killed_dedupe_set[42]=true`. When: `_on_enemy_despawned(42)`. Then: `_enemy_state_pool.has(42) == false`; `_killed_dedupe_set.has(42) == false`.

**Long-session (EC-47)**: Given: spawn 100 enemies (mock). When: call `_on_enemy_despawned` for all 100 instance_ids. Then: `_enemy_state_pool.is_empty() == true`; `_killed_dedupe_set.is_empty() == true`.

**HP update**: Given: enemy with `instance_id=7` in pool, `hp=100`. When: `_apply_hit_result(7, HitResult{target_hp_after: 65.0})`. Then: `_enemy_state_pool[7].hp == 65.0`. Edge: `_apply_hit_result(999, ...)` where 999 not in pool → no crash (guard check).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/integration/enemy_director/test_pool_cleanup.gd`
- `tests/unit/enemy_director/test_spawn_lifecycle.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 (`_spawn_pool` + `_enemy_state_pool` containers), 006 (RNGFactory sub-RNG), 010 (EnemyRegistry.tres), 011 (wave scheduler trigger)
- Unlocks: Stories 013 (AI state machine needs enemies spawned), 014 (locomotion needs pool), 015 (particle dispatch needs instance positions)
