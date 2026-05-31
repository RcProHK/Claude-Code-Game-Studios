# Story 011: Wave Archetype Scheduler (Rule 12 + Formula 1)

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31

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

**Readiness reconciliation (2026-05-31):**
- `WorkoutStateTracker.get_dominant_ability_class() -> int` EXISTS (returns AbilityClass ordinal: 0=STRIKE/1=CONTROL/2=MOBILITY/3=UNKNOWN). Accessed via new untyped `_wst_source` DI seam (resolves to WorkoutStateTracker autoload in `_ready`; tests inject a fake).
- GSM state is the `GameState.REST_PERIOD` enum (not a `"RestPeriod"` string) — `_on_state_changed` compares `to == GameStateMachine.GameState.REST_PERIOD`.
- New anomaly reasons `UNKNOWN_ABILITY_CLASS_FALLBACK` / `REGISTRY_LOOKUP_NULL` are GDD-sanctioned "future-extension reasons" (GDD Rule 6, §enemy-director.md:162 — the 6 core reasons are extensible). Add as StringName consts.
- **Scheduler is PAUSED by default** (`_wave_scheduler_paused = true`), unpaused only on `state_changed(to == COMBAT_ACTIVE)`, re-paused on `REST_PERIOD`. This is both correct (waves only spawn in combat) AND prevents the always-in-tree autoload's `_physics_process` from running the scheduler during unrelated tests (same determinism guard as Story 009's catch-up drain).
- Archetype mapping: `AbilityClass` ordinal → archetype StringName key (`&"STRIKE"` etc.). UNKNOWN/any-other → STRIKE fallback + EC-09 anomaly.
- `_spawn_enemy(wd)` is a Story 012 hook — Story 011 forwards to an injectable `_spawn_sink` seam (null no-op in production until Story 012) so EC-11 pool-cap (spawn called / not called) is observable.
- RestPeriod handler sets each `_enemy_state_pool` entry's `ai_state` to `EnemyAIState.IDLE` (pool entries are duck-typed until Story 012's EnemyState; tests inject mocks with an `ai_state` field).

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
**Status**: [x] Created; GUT 15/15 PASS (Godot 4.6.3, 2026-05-31); full suite 92/92

---

## Completion Notes

**Completed**: 2026-05-31
**Criteria**: 5/5 passing (EC-09, EC-10, EC-11, EC-13, Formula 1 + INV-1)
**Implementation**: Wave scheduler in enemy_director.gd — `_select_archetype_key` (AbilityClass→archetype key, UNKNOWN→STRIKE fallback + anomaly), `_resolve_active_wave` (registry null guard + REGISTRY_LOOKUP_NULL), `_compute_spawn_interval` (Formula 1 + INV-1 fail-loud assert), `_spawn_cadence_tick` (cadence accumulator, pool-cap EC-11), `_spawn_enemy` (injectable _spawn_sink hook), `_idle_active_enemies` (EC-13), `_on_state_changed` (COMBAT_ACTIVE unpause / REST_PERIOD pause+idle). New consts BASE_SPAWN_INTERVAL=4.0, MIN_SPAWN_INTERVAL=2.25, MAX_CONCURRENT_ENEMIES_ON_SCREEN=6; 2 reason consts; _wst_source + _spawn_sink DI seams.
**Key design**: scheduler PAUSED by default (combat-only + autoload _physics_process determinism guard). INV-1 = fail-loud assert NOT runtime clamp (anti-fabrication). UNKNOWN/registry-null fallbacks emit anomaly, never silent.
**Reviews**: godot-gdscript-specialist APPROVED WITH SUGGESTIONS; qa-tester TESTABLE (phantom-pass clean; EC-11 positive control verified; EC-13 real EnemyAIState.IDLE ref).
**Test Evidence**: tests/unit/enemy_director/test_wave_scheduler.gd (15 tests).
**Code Review**: Complete (full mode).
**Story 012 follow-ups** (from reviews): (1) tighten `_idle_active_enemies` silent-skip when an entry lacks ai_state (push_warning); (2) add null-entry guard test for _idle_active_enemies; (3) optionally add a real INV-1 assert-trip test (currently boundary-position substitute since assert() halts GUT). (4) `_resolve_active_wave` Variant typing nit.

---

## Dependencies

- Depends on: Stories 001, 005 (GSM subscription), 010 (EnemyRegistry.tres)
- Unlocks: Story 012 (spawn lifecycle triggered by scheduler), Story 016 (boss anchor needs wave tracking)
