# Story 019: enemy_killed Signal Chain + Idempotency (Rule 15)

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-014, TR-enemy-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 + ADR-0006
**ADR Decision Summary**: ADR-0005 mandates that `transition_id` from the CombatContext flows verbatim into `EnemyKilledPayload` — this is the RNG seed source for LootDrop; ADR-0006 mandates idempotent kill processing via `_killed_dedupe_set`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-36 [Integration|BLOCKING|integration]: Given `HitResult.is_kill == true`. When EnemyDirector emits `enemy_killed`. Then: payload `transition_id` field equals `ctx.transition_id` VERBATIM (string identity check — `payload.transition_id == ctx.transition_id`). This is the #15 LootDrop RNG seed source per ADR-0005 FR-2 chain.
- [ ] AC-37 [Logic|BLOCKING|unit]: Given same-frame double-resolve on same target instance_id (AOE × catch-up race). When second `resolve_hit` returns `is_kill=true` after first already emitted `enemy_killed`. Then: second emit BLOCKED by `_killed_dedupe_set.has(instance_id)` check; emit `combat_metric_anomaly(reason="DEAD_TARGET_RESOLVE")` instead; `enemy_killed` NOT emitted twice. (EC-17 + Rule 15)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Dedupe logic (runs after each `CombatResolver.resolve_hit(ctx)` call):
  ```
  if hit_result.is_kill:
      if not _killed_dedupe_set.has(ctx.target_instance_id):
          _killed_dedupe_set[ctx.target_instance_id] = true
          var payload = EnemyKilledPayload.new()
          payload.enemy_instance_id = ctx.target_instance_id
          payload.enemy_id = _enemy_state_pool[ctx.target_instance_id].enemy_id
          payload.transition_id = ctx.transition_id  # verbatim copy (not reference)
          payload.is_kill = true
          emit_signal("enemy_killed", payload)
      else:
          # Duplicate kill — rate-limited anomaly
          rate_limit_check("DEAD_TARGET_RESOLVE", now_ms)
          emit_signal("combat_metric_anomaly", CombatAnomalyPayload{reason: "DEAD_TARGET_RESOLVE", ...})
  ```
- `payload.transition_id = ctx.transition_id` — String copy (Strings are value types in GDScript; this is correct, NOT reference copy).
- String identity check: `payload.transition_id == ctx.transition_id` uses GDScript `==` which for String compares by value. Test with `assert(payload.transition_id == ctx.transition_id)`.
- Cleanup: `_on_enemy_despawned(instance_id)` (Story 012) erases both pool entry AND dedupe entry — dedupe set does not grow unboundedly.
- This story ONLY implements the dedupe guard and `enemy_killed` emit. The hit processing pipeline is Story 018.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 005: `enemy_killed` and `combat_metric_anomaly` signal declarations
- Story 007: Rate-limiter for DEAD_TARGET_RESOLVE anomaly
- Story 012: `_on_enemy_despawned()` that cleans the dedupe set
- Story 018: Full AOE pipeline that calls resolve_hit and triggers this logic

---

## QA Test Cases

**AC-36 transition_id verbatim**: Given: run `_on_ability_cast` with known `transition_id="TX-test-kill"` via mock GSM. Set mock CombatResolver to return `is_kill=true`. When: pipeline runs. Then: capture `enemy_killed` payload via signal recorder. Assert `payload.transition_id == "TX-test-kill"` (string equality). Assert `payload.transition_id` is a distinct String object (no aliasing needed — String value semantics guarantees correctness).

**AC-37 double-kill idempotency**: Given: manually insert `instance_id=42` into `_killed_dedupe_set`. When: AOE pipeline processes `instance_id=42` with `hit_result.is_kill=true`. Then: `enemy_killed` NOT emitted (signal recorder count stays 0 for this id); `combat_metric_anomaly` spy called with `reason=="DEAD_TARGET_RESOLVE"`. Repeat: call resolve same id again → anomaly count increments, but `enemy_killed` count stays 0.

Edge (same-frame race): enqueue 2 AOE hits both targeting instance_id=42. Process both in same drain cycle. Then: only 1 `enemy_killed` emitted; 1 `DEAD_TARGET_RESOLVE` anomaly emitted.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/enemy_director/test_enemy_killed_transition_id.gd`
- `tests/integration/enemy_director/test_enemy_killed_idempotent.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 005 (signals), 007 (rate-limiter), 017 (boss kill path), 018 (AOE pipeline triggers this)
- Unlocks: Epic Definition of Done — `enemy_killed` chain verified end-to-end; #15 LootDrop RNG seed verified
