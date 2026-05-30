# Story 009: EnemyDirector Integration Contract

> **Epic**: Combat Resolver
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (4+ hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

> ⚠️ **BLOCKED**: Depends on **#14 EnemyDirector** (Not Started / Pre-MVP tier). EnemyDirector owns:
> - `hit_resolved` / `enemy_killed` / `combat_metric_anomaly` signal emission
> - `ability_cast` subscription via `connect_for_initial_state` (ADR-0006 Contract 6)
> - AOE target iteration + `MAX_TARGETS_PER_CAST` clamp
> - GSM state snapshot into `ctx.gsm_state`
> Cannot implement or test this story until #14 EnemyDirector GDD is authored and implementation begins.

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-005`, `TR-combat-006`, `TR-combat-020`
*(TR-combat-005: EnemyDirector owns signal emission. TR-combat-006: HitResolvedPayload schema FR-2. TR-combat-020: GSM Suspended gate via ctx snapshot.)*

**ADR Governing Implementation**: ADR-0006 Contract 6 (`connect_for_initial_state` for ability_cast subscription by EnemyDirector); ADR-0006 Contract 3 (`EnemyKilledPayload` extends SerializableResource for FR-2 LootDrop chain).
**ADR Decision Summary**: CombatResolver emits NOTHING — all signal ownership resides in EnemyDirector. FR-4 (EnemyDirector 5-obligations contract) is the cornerstone contingent invariant: (a) subscribe ability_cast, (b) provide EnemyState struct, (c) inject RNG seeded on transition_id, (d) emit signals, (e) own anomaly rate-limiter + catch-up serialization.

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] **AC-06** — GIVEN fresh EnemyDirector autoload boot, WHEN `_ready()` completes, THEN EnemyDirector has subscribed `AbilitySystem.ability_cast` via `connect_for_initial_state` AND owns `hit_resolved`/`enemy_killed`/`combat_metric_anomaly` signal declarations. CombatResolver emits nothing. BLOCKED: requires #14.
- [ ] **AC-08** — GIVEN `HitResult.is_kill == true`, WHEN EnemyDirector emits `enemy_killed`, THEN payload propagates original `ctx.transition_id` verbatim (string identity). FR-2 binding. BLOCKED: requires #14.
- [ ] **AC-31** — GIVEN GSM state == &"Suspended" snapshotted into `ctx.gsm_state` by EnemyDirector, WHEN `CombatResolver.resolve_hit(ctx)` called, THEN Stage 1 rejects + returns `HitResult{damage_dealt=0}` AND EnemyDirector emits `combat_metric_anomaly(reason=GSM_SUSPENDED)`. EC-39 binding. BLOCKED: requires #14.
- [ ] **AC-32** — GIVEN `enemy_killed` signal with `EnemyKilledPayload`, WHEN downstream #15 LootDrop subscribes, THEN payload schema matches LootDrop's expected contract (shared `EnemyKilledPayload` resource). FR-2 end-to-end. BLOCKED: requires #14 + #15.
- [ ] **AC-33** — GIVEN `hit_resolved` signal, WHEN #5/#6/#25/#28 subscribe, THEN all 4 consumers receive same `HitResolvedPayload` same frame; `damage_tier` non-null. Multi-subscriber broadcast integrity. BLOCKED: requires #14 + downstream systems.

---

## Implementation Notes

*Deferred — see GDD Rule 3 (subscription ownership), Rule 8 (signal contract), FR-4 (EnemyDirector 5-obligations).*

Key considerations when unblocked:
- EnemyDirector must subscribe `ability_cast` via `connect_for_initial_state` (never plain `.connect`)
- EnemyDirector constructs `CombatContext` including `gsm_state` snapshot + `rng` seeded on `transition_id`
- EnemyDirector emits `hit_resolved(HitResolvedPayload.new().populate_from(hit_result, ctx))` after each `resolve_hit` call
- `EnemyKilledPayload` must extend `SerializableResource` (Story 002 defined) — verify `to_dict()`/`from_dict()` round-trip

---

## Out of Scope

Everything in stories 001-008 handles the core math. This story handles the #14 integration contract only.

---

## QA Test Cases

*Deferred — cannot define integration tests until #14 EnemyDirector authored.*

Placeholder: `*Integration tests deferred — BLOCKED on #14 EnemyDirector GDD authored + implementation begins.*`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/test_enemy_director_combat_contract.gd` — BLOCKED: not to be created until #14 implemented.

**Status**: [ ] BLOCKED — not to be created

---

## Dependencies

- Depends on: Stories 001-008 ALL Complete AND **#14 EnemyDirector** (Not Started) AND **#15 LootDrop** (for AC-32)
- Unlocks: Story 010 (ADR-Ratification-Gated benchmark requires full integration)
