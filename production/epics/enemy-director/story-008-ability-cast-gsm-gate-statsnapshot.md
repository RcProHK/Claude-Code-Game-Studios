# Story 008: _on_ability_cast Pipeline: GSM Gate + StatSnapshot

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-001, TR-enemy-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 Contract 2 (transition_id sync read)
**ADR Decision Summary**: ADR-0006 Contract 2 requires `transition_id` to be read synchronously from GSM at the moment of ability_cast — no async lookup, no cached value from a previous frame.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] (Story-level AC) Given `GSM.current_state == "Suspended"`. When `_on_ability_cast` fires. Then: reject immediately; emit `combat_metric_anomaly(reason=GSM_SUSPENDED)` rate-limited; no `CombatContext` built; no `CombatResolver` call. (EC-01)
- [ ] (Story-level AC) Given null caster parameter. When `_on_ability_cast` fires. Then: reject; emit anomaly `{reason: INVALID_ABILITY_ID, context_dump: {caster: null}}`; no ctx built. (EC-04)
- [ ] (Story-level AC) Given empty-string `transition_id` from GSM (malformed payload EC-45). When `_on_ability_cast` fires. Then: reject; emit anomaly `{reason: RNG_INJECTION_MISSING, context_dump: {transition_id: ""}}`; no ctx built.
- [ ] (Story-level AC) Given valid cast (non-Suspended, valid caster, valid `transition_id`). When `_build_stat_snapshot()` called. Then: `StatSystem.get_stat()` called EXACTLY 2 times (`ATTACK_POWER` + `CRIT_CHANCE`); same snapshot reference injected into ALL AOE target ctx (AOE mid-cast stat drift prevention per #13 Rule 6).

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

First 6 steps of `_on_ability_cast` handler:
1. Sync read: `var gsm_state = GameStateMachine.current_state`
2. If `gsm_state == GameState.SUSPENDED`: call `_anomaly_rate_tracker` via `rate_limit_check("GSM_SUSPENDED", now_ms)` → if passes emit anomaly → return
3. Validate caster param: if `caster == null` → emit anomaly `INVALID_ABILITY_ID` → return
4. Sync read: `var transition_id = GameStateMachine.current_transition_id`
5. If `transition_id.is_empty()`: emit anomaly `RNG_INJECTION_MISSING` → return
6. `var rng = _rng_factory.create(transition_id)`
7. `var snapshot = _build_stat_snapshot()`

`_build_stat_snapshot() -> StatSnapshot`:
- Call `StatSystem.get_stat(StatEnum.ATTACK_POWER)` → store
- Call `StatSystem.get_stat(StatEnum.CRIT_CHANCE)` → store
- Return immutable snapshot object
- EXACTLY 2 `StatSystem.get_stat()` calls per cast (enforced by CI lint Story 002)

DI seam: `StatSystem` must be untyped property for test injection (typed Node fails compile-time member check).

`CombatContext` (inner class or resource): `{ ability_def, caster, caster_stats: StatSnapshot, rng, transition_id, target_instance_id }`. One ctx per target, all share same `caster_stats` reference.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 005: Signal subscription that triggers this handler
- Story 006: RNGFactory that provides `rng`
- Story 007: Rate-limiter consumed here
- Story 009: AOE serialization mutex (catch-up queue check) — happens between steps 5 and 6
- Story 018: Full AOE target expansion + CombatResolver dispatch (continues from step 7)

---

## QA Test Cases

**Suspended gate**: Given: inject mock GSM returning `current_state == GameState.SUSPENDED`. When: `_on_ability_cast(ability_def, caster)`. Then: anomaly spy called with `reason == "GSM_SUSPENDED"`; combat resolver spy call count == 0.

**Null caster**: Given: inject valid GSM state. When: `_on_ability_cast(ability_def, null)`. Then: anomaly spy called with `reason == "INVALID_ABILITY_ID"`, `context_dump.caster == null`; resolver not called.

**Empty transition_id**: Given: inject mock GSM returning `current_transition_id == ""`. When: `_on_ability_cast(valid_ability, valid_caster)`. Then: anomaly spy called with `reason == "RNG_INJECTION_MISSING"`, `context_dump.transition_id == ""`; resolver not called.

**Stat snapshot**: Given: valid inputs. When: `_build_stat_snapshot()` called. Then: mock StatSystem spy received exactly 2 calls: `[ATTACK_POWER, CRIT_CHANCE]`. Given: 5-target AOE. Then: all 5 CombatContext objects reference identical `caster_stats` object (use `is_same()` identity check).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/enemy_director/test_ability_cast_gsm_gate.gd`
- `tests/unit/enemy_director/test_stat_snapshot.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 005 (signal subscription), 006 (RNGFactory), 007 (rate-limiter)
- Unlocks: Story 018 (full AOE pipeline builds on this gate + snapshot)
