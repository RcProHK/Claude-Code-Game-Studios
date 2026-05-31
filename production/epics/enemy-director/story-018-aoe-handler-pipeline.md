# Story 018: Full AOE Handler Pipeline (_on_ability_cast end-to-end)

> **Epic**: Enemy Director
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-002, TR-enemy-008, TR-enemy-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 + ADR-0005
**ADR Decision Summary**: ADR-0006 mandates serialized AOE processing with catch-up queue mutex; ADR-0005 mandates `transition_id` flows through all hit contexts for deterministic RNG chaining to LootDrop.

**Engine**: Godot 4.6 | **Risk**: HIGH

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-34 [Logic|BLOCKING|unit]: Given AOE `targets.size() == 12`. When EnemyDirector `_expand_targets()`. Then: distance-sort by `global_position.distance_squared_to(origin)`; clip to 8 nearest; emit `combat_metric_anomaly(reason="CLAMP_TRIGGERED", context_dump={requested:12, capped:8})`. (EC-21 + #13 Rule 14 `MAX_TARGETS_PER_CAST=8`)
- [ ] AC-35 [Integration|BLOCKING|integration]: Given AOE 5-target ability cast (non-Suspended, valid inputs). When full `_on_ability_cast` pipeline runs. Then:
  - (a) `StatSystem.get_stat()` called EXACTLY 2 times total (`ATTACK_POWER` + `CRIT_CHANCE`, in `_build_stat_snapshot()`)
  - (b) `CombatResolver.resolve_hit(ctx)` called EXACTLY 5 times (1 per target)
  - (c) 5 `hit_resolved` signals emitted
  - (d) all 5 ctx share same `caster_stats` snapshot reference (AOE mid-cast stat drift prevention)
  - (e) if any target killed, exactly 1 `enemy_killed` per unique instance_id (dedupe guard per Story 019)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- This story wires Stories 008 (GSM gate + snapshot) + 009 (catch-up mutex) + 006 (RNG) into the complete `_on_ability_cast` handler.
- Full pipeline order (all steps in `_on_ability_cast`):
  1. GSM gate (Story 008) — reject if Suspended/null caster/empty transition_id
  2. AOE/catch-up mutex check (Story 009) — defer if queue draining + AOE type
  3. `var rng = _rng_factory.create(transition_id)`
  4. `var snapshot = _build_stat_snapshot()` — 2 StatSystem calls
  5. `var targets = _get_ability_targets(ability_def, caster)` — radius query
  6. `_expand_targets(targets, origin)` — distance sort + clip to 8 (emit CLAMP_TRIGGERED if >8)
  7. For each target: build `CombatContext{ability_def, caster, caster_stats: snapshot, rng, transition_id, target_instance_id}`
  8. `var hit_result = CombatResolver.resolve_hit(ctx)` — static call per #13 Rule 2
  9. `_apply_hit_result(target_instance_id, hit_result)` — update pool HP
  10. Emit `hit_resolved(HitResolvedPayload{...transition_id})`
  11. If `hit_result.is_kill` and not in dedupe: emit `enemy_killed` + insert dedupe
- `CombatResolver.resolve_hit(ctx)` is a static func call (not instantiated — per #13 design).
- Emit order: `hit_resolved` per target → `enemy_killed` per killed target → `combat_metric_anomaly` if validation fail.
- All 5 CombatContext objects reference the SAME `snapshot` object (not copied) — verified by `is_same()`.
- `_expand_targets()`: sort by `distance_squared_to()` (cheaper than distance()); keep first 8.
- `MAX_TARGETS_PER_CAST = 8` — const.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 008: GSM gate + stat snapshot implementation
- Story 009: Catch-up queue mutex implementation
- Story 019: enemy_killed idempotency dedupe implementation
- Story 007: Rate-limiter for CLAMP_TRIGGERED anomaly

---

## QA Test Cases

**AC-34 target clamp**: Given: 12 mock EnemyState entries at varying distances from cast origin. When: `_expand_targets(targets, origin)`. Then: result has 8 entries; anomaly spy called with `reason=="CLAMP_TRIGGERED"`, `context_dump.requested==12`, `context_dump.capped==8`; verify the 8 returned ARE the 8 nearest by distance_squared.

**AC-35 full pipeline**: Given: inject mock StatSystem spy + mock CombatResolver spy returning HitResult{is_kill:false} + mock signal recorder. When: trigger `_on_ability_cast(aoe_ability_def, valid_caster)` with 5 targets. Then:
- StatSystem spy call count == 2 (ATTACK_POWER + CRIT_CHANCE)
- CombatResolver spy call count == 5
- Signal recorder `hit_resolved` count == 5
- All 5 CombatContext passed to resolver have `caster_stats` pointing to same object (use `is_same()`)
- Signal recorder `enemy_killed` count == 0 (no kills in this scenario)

Edge (AC-35e): repeat with 5 targets, mock resolver returns `is_kill=true` for instance_ids [1,2] on second call and fifth call. Then: `enemy_killed` emitted for instance_ids 1 and 2 only (dedupe ensures no double-emit even if resolver would return kill twice for same id).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/enemy_director/test_aoe_target_clamp.gd`
- `tests/integration/enemy_director/test_aoe_handler_pipeline.gd`
**Status**: [x] Created; GUT 11/11 (story) + 236/236 (suite+static) PASS; chokepoint/randf/stat/boss lints PASS (Godot 4.6.3, 2026-06-01)

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3 passing (AC-34 target clamp EC-21, AC-35 full pipeline incl AC-35e dedupe)
**Implementation**: completed `_on_ability_cast` Steps 8-11 — `_expand_targets` (distance-sort + clamp 8 + CLAMP_TRIGGERED), per-target loop building `CombatContext` (shared snapshot ref), `_resolve_hit` (injectable `_combat_resolver` seam → falls back to static CombatResolver.resolve_hit), `_emit_hit_resolved`, then `_apply_hit_result` (HP + dedup'd enemy_killed). `_get_ability_targets`, `_build_combat_context` (pool EnemyState → CombatResolver.EnemyState mapping, faction int→name), `_map_target_state`. Dedupe added to `_emit_enemy_killed` (_killed_dedupe_set, AC-35e). Const MAX_TARGETS_PER_CAST=8; _hit_seq_counter.
**Key**: CombatResolver.resolve_hit is static → mockable only via the `_combat_resolver` seam. All 5 AOE ctx share one snapshot reference (is_same verified). hit_resolved emits before enemy_killed per target.
**Test Evidence**: test_aoe_target_clamp.gd (4) + test_aoe_handler_pipeline.gd (7).
**Code Review**: deferred to batch review (autonomous epic completion run).

---

## Dependencies

- Depends on: Stories 005 (signals), 007 (rate-limiter), 008 (GSM gate + snapshot), 009 (catch-up mutex), 012 (pool HP update)
- Unlocks: Story 019 (enemy_killed chain needs pipeline end-to-end), epic integration DoD
