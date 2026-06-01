# Story 014: Signal Pipeline Integration — Autoload Position 7 + Class Affinity from #9

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-019`
*(Requirement: "44 ACs" — signal pipeline integration portion)*

**ADR Governing Implementation**: ADR-0002 (GymSys Integration Protocol, **Accepted-data-contract 2026-05-31** — signal/event contract Locked; transport Provisional/VS-gated) secondary; ADR-0005 (Accepted) primary; ADR-0008 (autoload position map) + ADR-0006 Contract 6 (connect_for_initial_state)
**ADR Decision Summary**: `LootDropSystem` boots **BEFORE** `EnemyDirector` — HARD constraint `LootDropSystem ≺ EnemyDirector` per ADR-0008 + `check_autoload_boot_order.gd` (#13 EC-43 / Rule 9: LootDrop must be fully booted before EnemyDirector wires its signals). Because EnemyDirector boots LATER, LootDrop defers its `enemy_killed` subscription to `_ready()` Step 5 (after `await _gymsys_client.backend_ready`, by which point all autoloads are constructed). `get_dominant_ability_class()` from #9 WorkoutStateTracker (boots at pos 8, BEFORE LootDrop) drives Formula E2 class affinity.

> **UNBLOCKED 2026-06-01**: #9 WorkoutStateTracker Complete ✅ + #14 EnemyDirector Complete ✅ (20/20 stories, merged). ADR-0002 signal/event contract now Locked (Accepted-data-contract). Boot order + signal wiring (AC-32/42/44) are testable without live HTTP transport (GymSysBackendClient stub emits `backend_ready`).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Autoload position in `project.godot` is source of truth per ADR-0008. Order is WorkoutStateTracker(8) → LootDropSystem(9) → EnemyDirector(10). LootDrop can connect to WST signals at its own `_ready` (WST in front); EnemyDirector signal subscription MUST wait until after the boot `await` (EnemyDirector constructed later).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-32** — Boot order + deferred signal wiring: `LootDropSystem` boots **BEFORE** `EnemyDirector` (HARD constraint `LootDropSystem ≺ EnemyDirector` per ADR-0008 + `check_autoload_boot_order.gd`; LootDrop pos 9 / EnemyDirector pos 10 — NOT "after"). Because EnemyDirector boots later, LootDrop subscribes to `EnemyDirector.enemy_killed` only at `_ready()` Step 5 (AFTER `await _gymsys_client.backend_ready`, by which point all autoloads incl. EnemyDirector are constructed). GSM state subscription uses `connect_for_initial_state` (ADR-0006 Contract 6); `enemy_killed` (event broadcast, not initial-state) uses raw `.connect()`. **Verify**: boot completes with no error; post-boot `EnemyDirector.enemy_killed.is_connected(_handle_enemy_killed) == true`.
- [ ] **AC-42** — Workout session chest-only (chest_volume = 100% total_volume) → daily LootDrop → `class_affinity_score[STRIKE] >= 0.65` (deterministic from #9 `get_dominant_ability_class()`; testable via MockWorkoutStateTracker returning `AbilityClass.STRIKE`).
- [ ] **AC-44** — `enemy_killed` → loot trigger end-to-end (mock-scoped): **GIVEN** LootDrop booted + subscribed, **WHEN** `EnemyDirector.enemy_killed` emits a valid `EnemyKilledPayload` (mock, non-empty `transition_id`), **THEN** `_handle_enemy_killed` fires with that transition_id; the transition_id flows verbatim into the loot RNG seed (ADR-0005 Pillar 1 chain). NO backend HTTP call (Story 013 scope).

---

## Implementation Notes

*Unblocked 2026-06-01 — #9 + #14 Complete. LootDropSystem autoload already registered in
`project.godot` at the correct position (LootDrop ≺ EnemyDirector). This story wires the
upstream signal subscriptions that Step 5 of `_ready()` currently stubs out.*

Key implementation points:
- LootDropSystem is **already** at the ratified position (pos 9, before EnemyDirector pos 10) —
  do NOT move it. AC-32 asserts the existing order, not a re-registration.
- In `_ready()` Step 5 (after `await _gymsys_client.backend_ready`):
  - `EnemyDirector.enemy_killed.connect(_handle_enemy_killed)` — raw `.connect()` (event broadcast,
    NOT initial-state; payload is an `EnemyKilledPayload` object carrying `transition_id` + `enemy_id`).
  - `WorkoutStateTracker.workout_completed_forwarded.connect(_handle_workout_completed)` — the actual
    WST signal is `workout_completed_forwarded(completed_at: int, transition_id: String)`; WST boots at
    pos 8 (before LootDrop) so this connection is safe at `_ready` time.
  - GSM `state_changed` already wired at Step 2 via `connect_for_initial_state` (Contract 6) — unchanged.
- **NO `boss_killed` signal** — EnemyDirector's surface is locked to 3 signals
  (`hit_resolved` / `enemy_killed` / `combat_metric_anomaly`). Boss kills arrive through
  `enemy_killed` with `enemy_id == boss_id`. The `_handle_boss_killed` handler is deferred until
  #16 Boss System lands (out of scope here).
- AC-42: integration test injecting `MockWorkoutStateTracker` (from `tests/helpers/`) with
  `get_dominant_ability_class()` returning `AbilityClass.STRIKE`; verify Formula E2 → `class_affinity_score[STRIKE] >= 0.65` (deterministic for fixed seed).
- AC-44: mock-emit `EnemyDirector.enemy_killed(EnemyKilledPayload)` with a known transition_id;
  assert `_handle_enemy_killed` receives it + transition_id seeds the loot RNG verbatim.

---

## Out of Scope

*Handled by neighbouring stories / deferred:*

- Backend HTTP authority / server tier correction — **Story 013** (blocked on #2 GymSys live transport, ADR-0002 transport Provisional)
- bfcache reconcile end-to-end composite flow — **Story 015** (blocked on #2)
- Loot generation formulas — **Stories 003-008** (Complete)
- `boss_killed` signal wiring — no such signal on EnemyDirector (locked 3-signal surface); boss kills arrive via `enemy_killed` with `enemy_id == boss_id`; dedicated #16 Boss System integration deferred until #16 implemented
- Real GymSys `backend_ready` transport (VS-gated per ADR-0002) — this story uses the GymSysBackendClient **stub** `backend_ready` emission

---

## QA Test Cases

**AC-32**: `test_autoload_boot_position.gd` — assert `LootDropSystem` autoload key precedes `EnemyDirector` in `project.godot` order (LootDrop ≺ EnemyDirector); after boot (`await` resolved), assert `EnemyDirector.enemy_killed.is_connected(_handle_enemy_killed)`.

**AC-42**: `test_class_affinity_derived_from_workout.gd` — inject MockWorkoutStateTracker returning `AbilityClass.STRIKE`; verify Formula E2 → `class_affinity_score[STRIKE] >= 0.65` (deterministic for fixed seed).

**AC-44**: `test_enemy_killed_loot_trigger.gd` — emit `EnemyDirector.enemy_killed` with a mock `EnemyKilledPayload` (transition_id="TX-loot-014"); assert `_handle_enemy_killed` invoked with that transition_id + transition_id seeds the loot RNG verbatim (no backend HTTP call).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: 
- `tests/integration/loot/test_autoload_boot_position.gd` (AC-32)
- `tests/integration/loot/test_class_affinity_derived_from_workout.gd` (AC-42)
- `tests/integration/loot/test_enemy_killed_loot_trigger.gd` (AC-44)

**Status**: [x] Created; GUT 14/14 PASS + 268/268 full loot suite (Godot 4.6.3, 2026-06-01)

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3 (AC-32 boot order + post-boot wiring, AC-42 class affinity STRIKE ≥65%, AC-44 enemy_killed → loot verbatim transition_id)
**Implementation**: `loot_drop_system.gd` Step 5 filled: resolves `_enemy_director` / `_workout_tracker` DI seams to production autoloads, wires `EnemyDirector.enemy_killed` → `_on_enemy_killed_payload` adapter + `WorkoutStateTracker.workout_completed_forwarded` → `_on_workout_completed_forwarded` adapter. Two adapter methods translate signal shapes (EnemyKilledPayload object / separate int+String params) to the existing 3-string / 2-param handler signatures. Added `get_active_workout_id()` + `get_workout_score()` to MockWorkoutStateTracker helper.
**Key discoveries**: (1) LootDropSystem.State.IDLE = 1, not 0 (BOOTING=0 would block triggers). (2) persistence stub required in AC-44b — without it, `write()` failure triggers optimistic rollback which erases `_drops_by_transition`, making transition_id unprovable. (3) `boss_killed` signal doesn't exist on EnemyDirector (locked 3-signal surface) — deferred to #16.
**Test Evidence**: test_autoload_boot_position.gd (3) + test_class_affinity_derived_from_workout.gd (6) + test_enemy_killed_loot_trigger.gd (5).

---

## Dependencies

- Depends on: Story 009 (autoload shell, Complete), Story 011 (trigger routing, Complete), **#9 WorkoutStateTracker (Complete ✅)**, **#14 EnemyDirector (Complete ✅)**
- Unlocks: Story 015 (full reconcile end-to-end — still BLOCKED on #2 GymSys live transport)
