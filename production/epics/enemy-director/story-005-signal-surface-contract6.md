# Story 005: Signal Surface + Contract 6 Subscription + Payload Schemas

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-005, TR-enemy-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 Contract 6 (connect_for_initial_state)
**ADR Decision Summary**: All signal subscriptions across the system must use `connect_for_initial_state` to guarantee late-joining subscribers receive initial state replay; raw `.connect()` is forbidden for inter-autoload subscriptions.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-06 [Integration|BLOCKING|integration]: After `_ready()` complete, EnemyDirector subscribed to `#1 GameStateMachine.state_changed` AND `#12 AbilitySystem.ability_cast` via `connect_for_initial_state` helper — late-bind initial state replay verified. Raw `.connect()` forbidden (CI lint Story 003).
- [ ] AC-07 [Logic|BLOCKING|unit]: `EnemyDirector.get_signal_list()` returns EXACTLY 3 signals: `hit_resolved` / `enemy_killed` / `combat_metric_anomaly`. No internal, debug, or extra signals.
- [ ] AC-08 [Logic|BLOCKING|unit]: `HitResolvedPayload` / `EnemyKilledPayload` / `CombatAnomalyPayload` struct fields match #13 GDD Rule 8/9/13 schemas exactly (field names + types verified). Payloads extend `RefCounted` or `SerializableResource` per ADR-0009.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Subscribe in `_ready()` LAST two lines per GDD Rule 2 pattern:
  1. `GameStateMachine.connect_for_initial_state(_on_state_changed)`
  2. `AbilitySystem.connect_for_initial_state(_on_ability_cast)`
- Payload classes declared as inner classes OR separate files in `src/autoload/`:
  - `HitResolvedPayload extends RefCounted`: fields — `transition_id: String`, `ability_id: StringName`, `caster_instance_id: int`, `target_instance_id: int`, `damage_dealt: float`, `is_crit: bool`, `damage_tier: int`, `hit_seq: int`
  - `EnemyKilledPayload extends RefCounted`: fields — `enemy_instance_id: int`, `enemy_id: StringName`, `transition_id: String`, `is_kill: bool`
  - `CombatAnomalyPayload extends RefCounted`: fields — `reason: StringName`, `aggregate: bool`, `dropped_count: int`, `context_dump: Dictionary`
- `hit_resolved` payload MUST include `transition_id: String` field — this is the #15 LootDrop RNG seed source per ADR-0005 FR-2 chain.
- ADR-0009: payloads are minimal + intrinsic (event data only); cross-cutting context (workout_id) late-bound at handler.
- DI seam: EnemyDirector must accept injected mock `GameStateMachine` and `AbilitySystem` via untyped properties (typed Node fails compile-time member check per GDScript DI seam constraint).

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: Class body declaration of containers
- Story 003: CI lint verifying connect_for_initial_state usage
- Story 007: Anomaly rate-limiter implementation (combat_metric_anomaly emit logic)
- Story 018: AOE handler that emits hit_resolved
- Story 019: enemy_killed emission logic

---

## QA Test Cases

**AC-06**: Given: fresh EnemyDirector with mock GSM + AbilitySystem injected (DI seam). When: `_ready()` completes. Then: `GameStateMachine.state_changed.is_connected(Callable(EnemyDirector,"_on_state_changed")) == true` AND `AbilitySystem.ability_cast.is_connected(Callable(EnemyDirector,"_on_ability_cast")) == true`. Edge: `connect_for_initial_state` delivers initial state replay — verify handler called on first connect with current state.

**AC-07**: Given: EnemyDirector instance. When: `get_signal_list()`. Then: returns Array of size 3; names equal `{hit_resolved, enemy_killed, combat_metric_anomaly}`; no extra signals present.

**AC-08**: Given: inspect `HitResolvedPayload` class vars. When: list all exported/public var names and types. Then: `transition_id: String`, `ability_id: StringName`, `caster_instance_id: int`, `target_instance_id: int`, `damage_dealt: float`, `is_crit: bool`, `damage_tier: int`, `hit_seq: int`. `EnemyKilledPayload`: `enemy_instance_id: int`, `enemy_id: StringName`, `transition_id: String`. `CombatAnomalyPayload`: `reason: StringName`, `aggregate: bool`, `dropped_count: int`, `context_dump: Dictionary`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/enemy_director/test_contract6_subscription.gd`
- `tests/unit/enemy_director/test_signal_surface.gd`
- `tests/unit/enemy_director/test_signal_payload_schemas.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (EnemyDirector class must exist)
- Unlocks: Stories 008 (GSM gate uses subscription), 018 (AOE pipeline emits signals), 019 (enemy_killed chain)
