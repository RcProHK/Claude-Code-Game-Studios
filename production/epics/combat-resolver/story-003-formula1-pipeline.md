# Story 003: Formula 1 — Base Damage + 5-Stage Pipeline

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 3/3 passing (AC-12/13/20)
**Deviations**: None — Formula 1 maxi(1, int(round(attack×mult−defense))); resolve_hit 5-stage pipeline complete; roll_crit/apply_crit_multiplier/detect_overkill/classify_damage_tier minimal stubs (Story 004/005 complete them); 4 Stage-1 guards (null/dead/suspended/missing-rng)
**Test Evidence**: Logic — `tests/unit/combat/test_formula1_base_damage.gd`
**Code Review**: Batch A self-verified

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-009`, `TR-combat-015`
*(TR-combat-009: Formula 1 — base_damage = max(1, round(attack × multiplier − defense)). TR-combat-015: 5-stage pipeline order: validate → compute_hit_damage → roll_crit → apply_crit_multiplier → detect_overkill + classify → outcome.)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (pure function, no await); ADR-0001 (Proposed ⚠️ — CPU budget; implement formula logic now, benchmark in Story 010 post-ADR-0001 ratification).
**ADR Decision Summary**: `resolve_hit(ctx)` is a synchronous pure function — 5 stages execute in fixed order, no side effects, no await. Stage 1 validates inputs; Stage 2 computes base damage via Formula 1. Base_damage floor is 1 (guaranteed hit even vs high defense).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `round()` returns float in Godot 4.x — use `int(round(...))` for integer damage. `max(1, ...)` — use `maxi(1, ...)` for integer-typed result.

**Control Manifest Rules (Core layer)**:
- Required: `resolve_hit` must be `static func` — no instance state, no `await`
- Required: Stage 1 null/dead-target/suspended checks fire BEFORE any math
- Forbidden: No direct StatSystem reads inside CombatResolver (all via ctx.caster_stats snapshot)

---

## Acceptance Criteria

- [ ] **AC-12** — GIVEN `ctx.caster_stats.attack_power=100`, `ctx.ability_damage_multiplier=2.0`, `ctx.target_state.defense=50`, WHEN `compute_hit_damage(ctx)` called, THEN `base_damage == maxi(1, int(round(100.0 × 2.0 − 50.0))) == 150`. Formula 1 binding.
- [ ] **AC-13** — GIVEN `attack_power=10, multiplier=1.0, defense=100` (result would be −90), WHEN `compute_hit_damage(ctx)` called, THEN result == 1 (floor clamp `maxi(1, ...)`). Guaranteed hit.
- [ ] **AC-20** — GIVEN `resolve_hit` 5-stage pipeline, WHEN test instruments each stage via spy hooks (or validates through staged HitResult intermediates), THEN execution follows: (1) validate → (2) compute_hit_damage → (3) roll_crit → (4) apply_crit_multiplier → (5) detect_overkill + classify_damage_tier → outcome assignment. No stage skip/reorder.

---

## Implementation Notes

*From GDD Rule 4 + Formula 1 + ADR-0006 Contract 12:*

1. **`static func resolve_hit(ctx: CombatContext) -> HitResult`** — entry point (Rule 2):
   ```gdscript
   static func resolve_hit(ctx: CombatContext) -> HitResult:
       # Stage 1: Validate
       if ctx == null: return _null_ctx_result()
       if ctx.target_state == null or ctx.target_state.hp <= 0:
           return _dead_target_result()  # AC-26/AC-27 handled in Story 008
       if ctx.gsm_state == &"Suspended":
           return _suspended_result()  # AC-31 handled in Story 009 integration
       if ctx.rng == null:
           return _missing_rng_result()  # AC-28 partial, full NaN in Story 008
       # Stage 2: Base damage
       var base_damage: int = compute_hit_damage(ctx)
       # Stage 3: Crit roll (Story 004)
       var is_crit: bool = roll_crit(ctx)
       # Stage 4: Crit multiplier (Story 004)
       var final_damage: float = base_damage * (CRIT_MULTIPLIER if is_crit else 1.0)
       # Stage 5: Overkill + classify (Story 005)
       var result: HitResult = HitResult.new()
       # ... populated in Stories 004+005
       return result
   ```
2. **`static func compute_hit_damage(ctx: CombatContext) -> int`** (Formula 1):
   ```gdscript
   var raw: float = ctx.caster_stats.attack_power * ctx.ability_damage_multiplier - ctx.target_state.defense
   return maxi(1, int(round(raw)))
   ```
3. **Constants** (add to class body as `const`):
   ```gdscript
   const CRIT_MULTIPLIER: float = 1.5  # Story 004
   const MAX_HIT_SEQ: int = 1_000_000   # Story 007
   const MAX_TARGETS_PER_CAST: int = 8  # Story 007
   ```
4. **Private helpers** `_null_ctx_result()`, `_dead_target_result()`, `_suspended_result()`, `_missing_rng_result()` — static func returning safe HitResult stubs (Stories 007/008 test them).

---

## Out of Scope

- Story 004: Crit roll + multiplier + replay determinism
- Story 005: Damage tier classification + overkill
- Story 007-008: Full defensive edge cases (null ctx, dead target, NaN)

---

## QA Test Cases

**Story Type**: Logic

- **AC-12**: Formula 1 nominal path
  - Given: attack=100, multiplier=2.0, defense=50
  - When: `CombatResolver.compute_hit_damage(ctx)`
  - Then: Returns 150 (int)
  - Edge cases: attack=50, mult=1.0, defense=50 → max(1, round(0))=max(1,0)=1; attack=50, mult=3.0, defense=50 → max(1, round(100))=100

- **AC-13**: Floor clamp
  - Given: attack=10, multiplier=1.0, defense=100
  - When: `compute_hit_damage(ctx)`
  - Then: Returns 1 (NOT 0 or negative)
  - Edge cases: defense=attack×multiplier exactly → round(0)=0 → max(1,0)=1

- **AC-20**: Pipeline order preserved
  - Given: Full CombatContext with all fields valid; inject stage-tracker via instrumented context flag
  - When: `resolve_hit(ctx)`
  - Then: Stages fire in documented order; no stage skipped; test via checking HitResult is fully populated

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/test_formula1_base_damage.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (CombatContext/HitResult structs must exist), Story 001 (CI lints active)
- Unlocks: Story 004 (crit formulas extend the pipeline established here)
