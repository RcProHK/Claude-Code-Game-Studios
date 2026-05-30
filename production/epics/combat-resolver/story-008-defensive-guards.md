# Story 008: Defensive Guards — Null, Dead Target, NaN

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-26/27/28)
**Deviations**: None — Stage-1 NaN/INF multiplier guard (→ _anomaly_result INVALID_ABILITY_ID); null ctx → safe NORMAL_HIT; dead target (hp≤0) → NORMAL_HIT NOT KILLED; all guards return damage_tier=NEGLIGIBLE (FR Test #4 never-null)
**Test Evidence**: test_defensive_guards.gd
**Code Review**: Batch C self-verified

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-017`
*(TR-combat-017: Null ctx + dead target + NaN multiplier safe handling.)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (pure function must never crash — defensive reject paths return safe HitResult).
**ADR Decision Summary**: `resolve_hit` guarantees no crash on bad inputs: null ctx, dead target (hp≤0), NaN multiplier. Each triggers a safe early-return HitResult with damage=0 and appropriate anomaly signal (emitted by EnemyDirector caller-side from the returned HitResult metadata).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `is_nan(float_val)` available as global function in Godot 4.x. Null check: `if ctx == null`. GDScript does NOT throw on null access — it returns null silently in some contexts; explicit null guard needed.

**Control Manifest Rules (Core layer)**:
- Required: `resolve_hit(null)` must return safe HitResult — never crash
- Required: Dead target (hp≤0) must return damage=0 and `outcome=NORMAL_HIT` (not KILLED — already dead)
- Required: NaN multiplier must be caught in Stage 1 before math — never propagate NaN through pipeline

---

## Acceptance Criteria

- [ ] **AC-26** — GIVEN `ctx == null`, WHEN `CombatResolver.resolve_hit(null)` called, THEN returns `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_tier=NEGLIGIBLE}` AND `push_error("[CombatResolver] null ctx")` logged AND no crash/exception. EC-01 binding.
- [ ] **AC-27** — GIVEN `ctx.target_state.hp == 0` (target already dead), WHEN `resolve_hit(ctx)` called, THEN `HitResult.damage_dealt == 0`, `outcome == NORMAL_HIT` (NOT KILLED — already dead, not a combat kill event), AND caller should emit `combat_metric_anomaly(reason=DEAD_TARGET_RESOLVE)`. EC-06 binding.
- [ ] **AC-28** — GIVEN `ctx.ability_damage_multiplier == NaN`, WHEN `compute_hit_damage` runs (Stage 2), THEN `is_nan(multiplier)` detected in Stage 1 → reject → return `HitResult{damage_dealt=0, damage_tier=NEGLIGIBLE}` AND caller emit `combat_metric_anomaly(reason=INVALID_ABILITY_ID, context_dump={"multiplier":"NaN"})`. No NaN propagation through pipeline. EC-12 binding.

---

## Implementation Notes

*From GDD Rules 4 (Stage 1), EC-01/EC-06/EC-12 + ADR-0006 Contract 12:*

1. **`_null_ctx_result() -> HitResult`** (static):
   ```gdscript
   push_error("[CombatResolver] resolve_hit: null ctx received")
   return HitResult.new()  # all defaults = 0/NORMAL_HIT/NEGLIGIBLE
   ```
2. **`_dead_target_result() -> HitResult`** (static): Same safe defaults. Caller (EnemyDirector) must emit anomaly DEAD_TARGET_RESOLVE when it receives this result (detected by `damage_dealt==0 and not is_kill`).
3. **NaN check in Stage 1** — before computing damage:
   ```gdscript
   if is_nan(ctx.ability_damage_multiplier):
       push_error("[CombatResolver] NaN multiplier for '%s'" % ctx.ability_id)
       return HitResult.new()  # safe zero result
   ```
4. **AC-27 clarification**: Dead target returns `outcome=NORMAL_HIT` (not KILLED) because KILLED means CombatResolver delivered the killing blow — the target is already dead, so no kill event should fire. EnemyDirector should detect `damage_dealt==0` and emit the DEAD_TARGET_RESOLVE anomaly.
5. **AC-27 test setup**: Set `ctx.target_state.hp = 0` before calling `resolve_hit`. Verify outcome is NORMAL_HIT (counterintuitive but correct per spec).

---

## Out of Scope

- Story 007: MAX_HIT_SEQ + Unicode safety (related boundary guards, different module)
- Story 009: GSM_SUSPENDED anomaly (integration test, requires EnemyDirector context)

---

## QA Test Cases

**Story Type**: Logic

- **AC-26**: Null ctx safe return
  - Given: resolve_hit(null)
  - When: Called
  - Then: Returns HitResult with damage=0, outcome=NORMAL_HIT; push_error fired; no crash
  - Edge cases: Called multiple times — each call independently safe

- **AC-27**: Dead target safe return
  - Given: ctx.target_state.hp=0
  - When: resolve_hit(ctx)
  - Then: damage_dealt=0, outcome=NORMAL_HIT (not KILLED); push_error or push_warning fired

- **AC-28**: NaN multiplier reject
  - Given: ctx.ability_damage_multiplier=NAN
  - When: resolve_hit(ctx)
  - Then: Returns HitResult{damage=0}; no NaN in result fields; push_error fired
  - Edge cases: INF multiplier → similar guard (is_inf check)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/test_defensive_guards.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (Stage 1 validation established; these guards extend it), Story 002 (AnomalyReason enum)
- Unlocks: Story 009 (EnemyDirector integration depends on complete defensive resolver)
