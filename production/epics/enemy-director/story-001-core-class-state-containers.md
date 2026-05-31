# Story 001: Core Class + 8 State Containers

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

**ADR Governing Implementation**: ADR-0006 Contract 4 (sequential autoload boot, state containers)
**ADR Decision Summary**: Autoloads must boot in defined sequential order; EnemyDirector must own all its state as class-body containers, never migrating state to other classes.

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-01 [Logic|BLOCKING|static]: 8 state containers declared in EnemyDirector class body: `_catch_up_queue: Array[CombatContext]` / `_anomaly_rate_tracker: Dictionary[StringName, RateWindow]` / `_enemy_state_pool: Dictionary[int, EnemyState]` / `_killed_dedupe_set: Dictionary[int, bool]` / `_spawn_pool: Dictionary[StringName, PackedScene]` / `_rng_factory: RNGFactory` / `_active_wave: WaveDescriptor` / `_boss_anchor_state: BossAnchorState` — CI lint `check_enemy_director_state_locality.gd` verifies
- [ ] AC-02 [Logic|BLOCKING|unit]: After `_ready()` complete, all 8 containers initialized to empty/zero-state: `_catch_up_queue.size()==0` / `_killed_dedupe_set.is_empty()` / `_boss_anchor_state==BossAnchorState.IDLE` / `_anomaly_rate_tracker.is_empty()` / `_enemy_state_pool.is_empty()` / `_spawn_pool` preloaded (not empty) / `_rng_factory != null`

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- `class_name EnemyDirector extends Node` — caller-side state owner, inverse of #13 stateless pure-function purity.
- All 8 containers MUST live in EnemyDirector class body (not migrated to other classes).
- `Faction` enum declared here: `enum Faction { PLAYER, ENEMY, BOSS, NEUTRAL }`.
- `EnemyAIState` + `BossAnchorState` enums follow ADR-0007 Family A (ordinal 0 = safe default).
- `_spawn_pool` preloaded from `EnemyRegistry.tres` in `_ready()` BEFORE signal subscription.
- Signal subscriptions are the LAST two lines of `_ready()` (per GDD Rule 2 pattern).
- DI seam: inject mock `EnemyRegistry` resource in tests; do NOT reference autoload directly inside `_ready()` for the registry load.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: CI lint scripts that verify state locality (check_enemy_director_state_locality.gd)
- Story 005: Signal subscription logic and contract 6 connect_for_initial_state
- Story 006: RNGFactory inner class implementation (just declare `_rng_factory` here)
- Story 010: EnemyRegistry.tres data file population

---

## QA Test Cases

**AC-01**: Given: source file `src/autoload/enemy_director.gd`. When: scan via `check_enemy_director_state_locality.gd`. Then: all 8 container names present as class body vars; scan returns 0 violations.

**AC-02**: Given: EnemyDirector fresh autoload after `_ready()`. When: inspect each of the 8 containers. Then:
- `_catch_up_queue.size() == 0`
- `_killed_dedupe_set.is_empty() == true`
- `_boss_anchor_state == BossAnchorState.IDLE` (ordinal 0)
- `_anomaly_rate_tracker.is_empty() == true`
- `_enemy_state_pool.is_empty() == true`
- `_rng_factory != null`
- `_spawn_pool` not empty (preloaded)

Edge: In test env inject mock EnemyRegistry; verify `_spawn_pool` populated after `_ready()`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_director/test_init_state.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Stories 002-004 (CI lints reference EnemyDirector source), Story 005 (signal subscription), Story 006 (RNGFactory), Story 011 (wave scheduler), Story 016 (boss anchor)
