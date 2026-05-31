# Story 005: Signal Surface + Contract 6 Subscription + Payload Schemas

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31

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

- [x] AC-06 [Integration|BLOCKING|integration]: After `_ready()` complete, EnemyDirector subscribed to `#1 GameStateMachine.state_changed` AND `#12 AbilitySystem.ability_cast` via `connect_for_initial_state` helper — late-bind initial state replay verified. Raw `.connect()` forbidden (CI lint Story 003).
- [x] AC-07 [Logic|BLOCKING|unit]: `EnemyDirector.get_signal_list()` returns EXACTLY 3 signals: `hit_resolved` / `enemy_killed` / `combat_metric_anomaly`. No internal, debug, or extra signals.
- [x] AC-08 [Logic|BLOCKING|unit]: `HitResolvedPayload` / `EnemyKilledPayload` / `CombatAnomalyPayload` struct fields match #13 GDD Rule 8/9/13 schemas exactly (field names + types verified). Payloads extend `RefCounted` or `SerializableResource` per ADR-0009.
- [x] AC-09 [Logic|BLOCKING|unit]: `AbilitySystem.connect_for_initial_state(callable: Callable)` added to `src/autoload/ability_system.gd` — thin wrapper that calls `ability_cast.connect(callable)` directly (NO initial-state replay sentinel, since `ability_cast` is an event signal not a state carrier). Test: callable connected after call; NOT a duplicate of GSM's sentinel-replay logic. Regression: existing AbilitySystem unit suite still passes.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Subscribe in `_ready()` LAST two lines per GDD Rule 2 pattern:
  1. `GameStateMachine.connect_for_initial_state(_on_state_changed)` — GSM exposes this helper (ADR-0006 Contract 6 sentinel pattern).
  2. `AbilitySystem.ability_cast.connect(_on_ability_cast)` — ability_cast is a regular event signal (not a state signal; no replay needed). NOTE: CI lint Story 003 (`check_enemy_director_signal_subscription.gd`) forbids the raw `AbilitySystem.ability_cast.connect(` literal pattern to prevent future misuse. To satisfy the lint while connecting normally, Story 005 adds `connect_for_initial_state` to AbilitySystem (a thin wrapper that calls `ability_cast.connect()` directly, without the state-replay sentinel, since ability_cast has no initial-state to replay). This is in-scope for this story — add the method to `src/autoload/ability_system.gd` before wiring EnemyDirector.
- Payload classes — **ground truth is the already-implemented classes**; DO NOT redefine:
  - `HitResolvedPayload` (inner class at `src/core/combat_resolver.gd:161`): `ability_id: StringName`, `caster_id: int`, `target_id: int`, `outcome: HitOutcome`, `damage_tier: DamageTier`, `damage_dealt: int`, `damage_raw: float`, `target_hp_after: int`, `is_crit: bool`, `is_kill: bool`, `transition_id: String`, `resolved_at_tick: int`
  - `EnemyKilledPayload` (at `src/core/enemy_killed_payload.gd`): `enemy_id: StringName`, `enemy_instance_id: int`, `killer_id: int`, `killing_ability: StringName`, `transition_id: String`, `is_overkill: bool`, `overkill_excess: int` — **DO NOT create a new version; import/use the existing class**
  - `CombatAnomalyPayload` (to be created as NEW class at `src/core/combat_anomaly_payload.gd`): fields — `reason: StringName`, `aggregate: bool`, `dropped_count: int`, `context_dump: Dictionary` — extends `RefCounted` (transient event notification to #28 Telemetry; never persisted, no to_dict/from_dict required). `class_name CombatAnomalyPayload`.
- `hit_resolved` payload MUST include `transition_id: String` field ✓ (already in HitResolvedPayload).
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

**AC-08**: Given: inspect payload class vars (source of truth = actual implemented classes). When: list all public var names. Then:
- `HitResolvedPayload` (src/core/combat_resolver.gd:161): `ability_id: StringName`, `caster_id: int`, `target_id: int`, `outcome: HitOutcome`, `damage_tier: DamageTier`, `damage_dealt: int`, `damage_raw: float`, `target_hp_after: int`, `is_crit: bool`, `is_kill: bool`, `transition_id: String`, `resolved_at_tick: int` ✓ already implemented.
- `EnemyKilledPayload` (src/core/enemy_killed_payload.gd): `enemy_id: StringName`, `enemy_instance_id: int`, `killer_id: int`, `killing_ability: StringName`, `transition_id: String`, `is_overkill: bool`, `overkill_excess: int` ✓ already implemented. Story 005 verifies fields present and `transition_id` non-null (ADR-0005 RNG chain).
- `CombatAnomalyPayload` (NEW — to be created by this story): `reason: StringName`, `aggregate: bool`, `dropped_count: int`, `context_dump: Dictionary`. Extends `RefCounted` per ADR-0009. Must be accessible as `CombatAnomalyPayload` globally.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/enemy_director/test_contract6_subscription.gd`
- `tests/unit/enemy_director/test_signal_surface.gd`
- `tests/unit/enemy_director/test_signal_payload_schemas.gd`
**Status**: [x] Complete — 4 ACs verified; GUT 29/29 enemy + 84/84 ability PASS (Godot 4.6.2, 2026-05-31)

---

## Completion Notes

**Completed**: 2026-05-31
**Criteria**: 4/4 passing (AC-06 wiring, AC-07 signal lock, AC-08 payload schemas, AC-09 wrapper)
**Key discovery**: `AbilitySystem.connect_for_initial_state` was ALREADY implemented (ability_system.gd:406, correct no-sentinel-replay semantics) — AC-09 tests verify the existing method; no new wrapper needed.
**Implementation**:
- `src/autoload/enemy_director.gd` — `_gsm_source`/`_ability_source` untyped DI seams + `_ready()` Contract 6 subscription wiring + `_on_state_changed`/`_on_ability_cast` stub handlers (full logic deferred to Story 008).
- `src/core/combat_anomaly_payload.gd` — NEW `CombatAnomalyPayload extends RefCounted` (transient telemetry, ADR-0009 §1).
- `tests/unit/enemy_director/test_init_state.gd` — Story 001 regression fix: inject FakeGSM/FakeAbilitySystem in before_each so _ready() subscription wiring uses fakes.
**Review fixes applied**:
- BLOCKING (qa-tester): AC-08 HitResolvedPayload now locks all 12 fields via default-value assertions (was 7/12 assert_not_null) — type-locking incl. damage_tier "NEVER null" invariant.
- ADVISORY: ability_cast fires_handler test now re-asserts is_connected (was tautological); test_signal_surface.gd orphan Node probe now free()'d.
**Deviations (deferred to Story 008)**:
- _on_state_changed must handle GSM sentinel initial-state replay (from==to, source_event=="initial_state") — stub currently no-op.
- before_each _ready() re-run doesn't disconnect boot-time real-autoload connection — harmless (no-op stubs) but clean up when Story 008 gives handlers real behavior.
**Test Evidence**: 4 test files (4+4+7+3 = 18 Story 005 tests). GUT green.
**Code Review**: Complete — GDScript ADEQUATE (0 CRITICAL/MAJOR); qa-tester TESTABLE (BLOCKING gap fixed).

---

## Dependencies

- Depends on: Story 001 (EnemyDirector class must exist)
- Unlocks: Stories 008 (GSM gate uses subscription), 018 (AOE pipeline emits signals), 019 (enemy_killed chain)
