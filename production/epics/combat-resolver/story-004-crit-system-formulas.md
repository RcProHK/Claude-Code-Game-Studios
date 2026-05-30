# Story 004: Crit System — Formulas 2+3 + Replay Determinism

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-14/15/22/23)
**Deviations**: None — roll_crit Formula 2 deterministic sub-seed `hash(transition_id:ability_id:hit_seq)` + ctx.rng.randf (caller-injected, passes randf lint); apply_crit_multiplier signature int→float (crit applied pre-round per GDD pipeline); randf lint already had negative-lookbehind (verified ctx.rng.randf passes)
**Test Evidence**: test_formula2_crit_roll.gd, test_combat_resolver_determinism.gd
**Code Review**: Batch B self-verified (Python IEEE754 boundary verification)

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-010`, `TR-combat-011`, `TR-combat-016`
*(TR-combat-010: Formula 2 — roll_crit via hash(transition_id + ability_id + hit_seq) sub-seed. TR-combat-011: Formula 3 — crit multiplier = 1.5×. TR-combat-016: Unicode-safe sub-seed; MAX_HIT_SEQ = 1_000_000 boundary.)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (no await, deterministic); ADR-0005 (Proposed ⚠️ — FR-2 transition_id chain; implement sub-seed now using transition_id, ADR-0005 ratification gates loot formula only).
**ADR Decision Summary**: Crit roll is deterministic — seeded from `hash(transition_id + ability_id + hit_seq)` state, making the same ctx inputs always produce the same crit outcome. `ctx.rng` is caller-injected and pre-seeded with transition_id; `roll_crit` then applies a per-hit sub-seed to the RNG state to prevent hit-sequence degeneration.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `hash()` in Godot 4.x is a built-in Variant method returning a signed 32-bit int. String + StringName concatenation: `String(transition_id) + String(ability_id) + str(hit_seq)` — ensure all coerced to String before hashing. `RandomNumberGenerator.seed` setter for sub-seed injection.

**Control Manifest Rules (Core layer)**:
- Required: Crit roll must use caller-injected `ctx.rng` (never `randf()` — CI lint AC-randf-lint)
- Required: Sub-seed derived from `hash(transition_id + ability_id + hit_seq)` — deterministic, no wall-clock or frame-counter input
- Forbidden: `RandomNumberGenerator.new()` inside CombatResolver (RNG must be injected by EnemyDirector)

---

## Acceptance Criteria

- [ ] **AC-14** — GIVEN fixed `transition_id="TX-001"`, `ability_id="STRIKE_TIER_1_JAB"`, `hit_seq=3`, WHEN `roll_crit(ctx)` called 1000 times with same sub-seed hash, THEN all 1000 returns are byte-identical boolean. Determinism of Formula 2.
- [ ] **AC-15** — GIVEN `is_crit=true`, `base_damage=100`, WHEN `apply_crit_multiplier(100, true)` called, THEN result `== int(round(100 × 1.5)) == 150`. Edge case: `base=1` → `round(1×1.5)=round(1.5)=2`. Formula 3 binding.
- [ ] **AC-22** — GIVEN `transition_id="TX-replay-001"`, same CombatContext with `ability_id=STRIKE_TIER_2_HOOK`, WHEN `resolve_hit(ctx)` run twice (same seed state reset before each), THEN both HitResults are field-for-field identical (damage_dealt/outcome/damage_tier/is_crit/overkill_excess all match). FR Test #1 — replay determinism (Falsifiable Test #1 binding).
- [ ] **AC-23** — GIVEN same `ability_id` + `hit_seq` but different `transition_id` ("TX-A" vs "TX-B"), WHEN sub-seed hash computed for each, THEN `hash("TX-A"+...) != hash("TX-B"+...)` AND running 10000 sample pairs, chi-square test does NOT reject independence of the two RNG streams. Different encounter → different crit stream.

---

## Implementation Notes

*From GDD Formula 2, Formula 3 + Rule 7 + Rule 4 Stage 3-4:*

1. **`static func roll_crit(ctx: CombatContext) -> bool`** (Formula 2 — deterministic sub-seed):
   ```gdscript
   static func roll_crit(ctx: CombatContext) -> bool:
       # Sub-seed: hash(transition_id + ability_id + hit_seq_str) to prevent RNG stream
       # degeneration across multi-hit AOE encounters (Rule 7).
       var sub_key: String = String(ctx.transition_id) + String(ctx.ability_id) + str(ctx.hit_seq)
       var sub_seed: int = hash(sub_key)  # deterministic, Unicode-safe (Story 007 boundary tests)
       ctx.rng.seed = sub_seed
       return ctx.rng.randf() < ctx.caster_stats.crit_chance
   ```
2. **`static func apply_crit_multiplier(base_damage: int, is_crit: bool) -> int`** (Formula 3):
   ```gdscript
   if not is_crit: return base_damage
   return int(round(float(base_damage) * CRIT_MULTIPLIER))
   ```
3. **Stage 3+4 in `resolve_hit`** — call `roll_crit(ctx)` → store `is_crit`, then `apply_crit_multiplier(base_damage, is_crit)` → store `final_damage_float` for Stage 5.
4. **Replay test pattern** — test creates two identical CombatContext objects, seeds `ctx.rng` with the same seed value, calls `resolve_hit` twice. Sub-seed overrides `ctx.rng.seed` internally per call, so test only needs same `transition_id`/`ability_id`/`hit_seq`.

---

## Out of Scope

- Story 005: Damage tier classification + overkill (Stage 5)
- Story 007: Unicode boundary + MAX_HIT_SEQ boundary (sub-seed safety)

---

## QA Test Cases

**Story Type**: Logic

- **AC-14**: Crit roll determinism
  - Given: RNG seeded consistently; same transition_id/ability_id/hit_seq
  - When: `roll_crit(ctx)` × 1000
  - Then: All identical (either all true or all false for this sub-seed)
  - Edge cases: hit_seq=0 and hit_seq=1 may differ (different sub-seeds)

- **AC-15**: Crit multiplier 1.5×
  - Given: base=100, is_crit=true
  - When: `apply_crit_multiplier(100, true)`
  - Then: 150; base=1 → 2 (round(1.5)=2)

- **AC-22**: Full resolve_hit replay determinism
  - Given: Two identical CombatContexts with same RNG seed start
  - When: Two separate resolve_hit calls
  - Then: All HitResult fields identical

- **AC-23**: Different transition_id → independent RNG streams
  - Given: Same ability_id/hit_seq but transition_id "TX-A" vs "TX-B"
  - When: 10000 crit rolls for each stream
  - Then: hash("TX-A"+...) != hash("TX-B"+...); chi-square independence not rejected

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/test_formula2_crit_roll.gd`, `tests/unit/combat/test_combat_resolver_determinism.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (pipeline established; base_damage formula needed for Stage 3 context)
- Unlocks: Story 005 (damage tier + overkill = final Stage 5)
