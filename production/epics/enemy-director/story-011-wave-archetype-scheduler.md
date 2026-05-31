# Story 011: Wave Archetype Scheduler (Rule 12 + Formula 1)

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-001, TR-enemy-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 + ADR-0007
**ADR Decision Summary**: ADR-0006 mandates sequential processing and state machine integrity for wave scheduling; ADR-0007 mandates UNKNOWN as last sentinel in classification enums with explicit fallback behavior when UNKNOWN is returned.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] (Story-level AC) Given `WorkoutStateTracker.get_dominant_ability_class()` returns `UNKNOWN`. When wave scheduler tick. Then: default to STRIKE archetype; emit `combat_metric_anomaly(reason="UNKNOWN_ABILITY_CLASS_FALLBACK")` rate-limited. (EC-09)
- [ ] (Story-level AC) Given `EnemyRegistry.tres` lookup returns `null` for current archetype (registry schema bug). When scheduler tick. Then: log error; emit anomaly `{reason: "REGISTRY_LOOKUP_NULL"}`; skip wave; EnemyDirector falls to Idle. (EC-10)
- [ ] (Story-level AC) Given `_enemy_state_pool.size() >= MAX_CONCURRENT_ENEMIES_ON_SCREEN = 6` (mobile cap). When spawn cadence tick fires. Then: spawn paused; resume when pool size drops below cap. No anomaly emitted (legitimate cap behavior). (EC-11)
- [ ] (Story-level AC) Given `GSM.current_state == "RestPeriod"`. When wave_scheduler receives `state_changed`. Then: `wave_scheduler.pause()`; existing enemies in pool set AI state → IDLE; no despawn (preserve narrative continuity). (EC-13)
- [ ] (Story-level AC) Formula 1 worked examples:
  - `actual_spawn_interval = BASE_SPAWN_INTERVAL × archetype_cadence_mult`
  - MOBILITY: `BASE=4.0 × mult=0.75 = 3.0s actual interval`
  - STRIKE: `BASE=4.0 × mult=1.0 = 4.0s actual interval`
  - INV-1: `BASE × min_mult = 4.0 × 0.75 = 3.0 ≥ 2.25` ✓

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Wave scheduler tick called from `_physics_process(delta)` via `_spawn_cadence_tick(delta)`.
- `_spawn_cadence_accumulator: float` tracks time since last spawn. When `>= actual_spawn_interval`: trigger spawn if pool slot available.
- Read `WorkoutStateTracker.get_dominant_ability_class()` each scheduler tick (DI seam — mock WST in tests; untyped property).
- `UNKNOWN` fallback: if `get_dominant_ability_class() == AbilityClass.UNKNOWN` → use `STRIKE` archetype + rate-limited anomaly emit.
- Registry null guard: if `EnemyRegistry.archetypes.get(archetype_key, null) == null` → log error + emit anomaly + skip spawn + reset to IDLE (do NOT crash).
- Pool cap: `MAX_CONCURRENT_ENEMIES_ON_SCREEN = 6` — const. No spawn while `_enemy_state_pool.size() >= 6`. No anomaly (legitimate behavior; just pause).
- RestPeriod gate: subscribe to GSM `state_changed` (via `connect_for_initial_state` Story 005). On `to == "RestPeriod"`: set `_wave_scheduler_paused = true`; iterate `_enemy_state_pool` and set each enemy AI state to IDLE.
- `_active_wave: WaveDescriptor` holds current archetype descriptor. Update on archetype change.
- `BASE_SPAWN_INTERVAL = 4.0` seconds (const).

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: `_active_wave` container declaration
- Story 005: GSM state_changed subscription
- Story 010: EnemyRegistry.tres data (must exist before scheduler reads it)
- Story 012: Actual `_spawn_enemy()` call (scheduler triggers it, spawn lifecycle owns it)
- Story 016: Boss anchor trigger (boss spawning is a separate flow from wave scheduler)

---

## QA Test Cases

**UNKNOWN fallback (EC-09)**: Given: inject mock WST returning `AbilityClass.UNKNOWN`. When: scheduler tick. Then: `_active_wave` == STRIKE descriptor; anomaly spy called with `reason=="UNKNOWN_ABILITY_CLASS_FALLBACK"`.

**Registry null (EC-10)**: Given: inject mock registry returning null for any key. When: scheduler tick. Then: no spawn attempted; anomaly spy called `reason=="REGISTRY_LOOKUP_NULL"`; `_boss_anchor_state` or wave state reset to Idle.

**Pool cap (EC-11)**: Given: `_enemy_state_pool.size() == 6`. When: cadence timer triggers. Then: `_spawn_enemy` NOT called; no anomaly emitted. Given: pool drops to 5. When: next cadence timer. Then: `_spawn_enemy` called.

**RestPeriod (EC-13)**: Given: inject GSM state_changed `to="RestPeriod"`. When: handler fires. Then: `_wave_scheduler_paused == true`; each mock enemy in pool received AI state → IDLE; `_enemy_state_pool` not empty (enemies preserved).

**Formula 1**: Given: MOBILITY archetype loaded (`archetype_cadence_mult=0.75`), `BASE_SPAWN_INTERVAL=4.0`. When: compute `actual_spawn_interval`. Then: `actual_spawn_interval == 3.0`. Given: STRIKE (`mult=1.0`). Then: `actual_spawn_interval == 4.0`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_director/test_wave_scheduler.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 005 (GSM subscription), 010 (EnemyRegistry.tres)
- Unlocks: Story 012 (spawn lifecycle triggered by scheduler), Story 016 (boss anchor needs wave tracking)
