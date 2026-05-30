# Story 005: Damage Tier + Overkill — Formulas 4+5

> **Epic**: Combat Resolver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-16 corrected/AC-17/18/19/30)
**Deviations**: AC-16 text had a typo ([9→LIGHT, 400→HEAVY] don't match GDD Formula 4 `>=` thresholds) — corrected to GDD-faithful boundaries; impl follows GDD verbatim. detect_overkill/classify_damage_tier signatures finalized to GDD form.
**Test Evidence**: test_formula4_damage_tier.gd, test_formula5_overkill.gd
**Code Review**: Batch B self-verified (GDD Formula 4 = authority for the AC-16 reconcile)

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-012`, `TR-combat-013`
*(TR-combat-012: Formula 4 — 5-tier damage classification (ratio thresholds 0.01/0.05/0.15/0.40 of max_hp); crit forces ≥HEAVY. TR-combat-013: Formula 5 — overkill clamp + expose overkill_excess.)*

**ADR Governing Implementation**: ADR-0006 Contract 12 (pure function); ADR-0001 (Proposed — performance guardrail; formulas are O(1) so budget not a concern here).
**ADR Decision Summary**: `classify_damage_tier` maps damage/max_hp ratio to DamageTier enum; crit hit always elevates tier to ≥HEAVY (FR Test #4 mandatory). `detect_overkill` clamps damage_dealt to target.hp and exposes overkill_excess for downstream Boss System and VFX.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Float division `float(damage_dealt) / float(target_state.max_hp)` — guard against `max_hp==0` (AC-30). `maxi` for integer clamp.

**Control Manifest Rules (Core layer)**:
- Required: `damage_tier` in HitResult/HitResolvedPayload MUST NOT be null — always classified (FR Test #4)
- Required: Crit hit MUST produce `damage_tier ≥ DamageTier.HEAVY` even when damage ratio would classify lower

---

## Acceptance Criteria

- [ ] **AC-16** — GIVEN `target.max_hp=1000`, WHEN `classify_damage_tier` called with `damage_dealt` and `is_crit=false`, THEN tiers follow GDD Formula 4 `>=`-inclusive thresholds (0.01/0.05/0.15/0.40). Boundary verification: [5→NEGLIGIBLE, 10→LIGHT(0.01 exact), 50→MEDIUM(0.05 exact), 149→MEDIUM, 150→HEAVY(0.15 exact), 400→CRITICAL(0.40 exact), 401→CRITICAL]. *(CORRECTED 2026-05-30: original AC-16 text `[9→LIGHT, 400→HEAVY]` was a typo — 9/1000=0.009 < 0.01 → NEGLIGIBLE; 400/1000=0.40 == T_CRITICAL → CRITICAL. GDD Formula 4 is the authority per coding-standards "balance values link to source formula".)*
- [ ] **AC-17** — GIVEN `is_crit=true`, `damage_dealt=20`, `target.max_hp=1000` (ratio=0.02, normally LIGHT), WHEN `classify_damage_tier` called, THEN tier == `DamageTier.HEAVY` (crit override forces ≥HEAVY per Rule 10). FR Test #4 binding.
- [ ] **AC-18** — GIVEN `target.hp=50, damage_raw=200.0`, WHEN `detect_overkill` called, THEN `damage_dealt==50` (clamped to hp), `outcome==OVERKILL`, `overkill_excess==150`. Formula 5 binding.
- [ ] **AC-19** — GIVEN `target.hp=50, damage_raw=50.0` (exact kill), WHEN `detect_overkill` called, THEN `outcome==KILLED` (NOT OVERKILL), `overkill_excess==0`. Boundary EC-22: exact damage == hp → KILLED.
- [ ] **AC-30** — GIVEN `target.max_hp==1`, `damage_dealt=1` (ratio=1.0), WHEN `classify_damage_tier` called, THEN tier == `DamageTier.CRITICAL` and NO div-by-zero / NaN. Boundary EC-18.

---

## Implementation Notes

*From GDD Rules 4, 10 + Formulas 4+5 + EC-18/EC-22:*

1. **`static func classify_damage_tier(damage_dealt: int, target_max_hp: int, is_crit: bool) -> DamageTier`** (Formula 4):
   ```gdscript
   if target_max_hp <= 0: return DamageTier.CRITICAL  # guard against div-by-zero (AC-30)
   var ratio: float = float(damage_dealt) / float(target_max_hp)
   var tier: DamageTier
   if ratio < 0.01: tier = DamageTier.NEGLIGIBLE
   elif ratio < 0.05: tier = DamageTier.LIGHT
   elif ratio < 0.15: tier = DamageTier.MEDIUM
   elif ratio < 0.40: tier = DamageTier.HEAVY
   else: tier = DamageTier.CRITICAL
   # Crit override: force ≥ HEAVY (FR Test #4 — damage_tier MUST reflect crit)
   if is_crit and tier < DamageTier.HEAVY:
       tier = DamageTier.HEAVY
   return tier
   ```
2. **`static func detect_overkill(damage_raw: float, target_hp: int) -> Dictionary`** (Formula 5):
   Returns `{damage_dealt, overkill_excess, target_hp_after, is_kill}`:
   ```gdscript
   var damage_as_int: int = int(round(damage_raw))  # convert float → int
   if damage_as_int >= target_hp:
       return {
           "damage_dealt": target_hp,
           "overkill_excess": damage_as_int - target_hp,  # 0 if exact kill
           "target_hp_after": 0,
           "is_kill": true,
       }
   return {
       "damage_dealt": damage_as_int,
       "overkill_excess": 0,
       "target_hp_after": target_hp - damage_as_int,
       "is_kill": false,
   }
   ```
   Note: AC-19 exact-kill: `damage_as_int == target_hp` → `overkill_excess = 0` → outcome = KILLED (not OVERKILL). `overkill_excess > 0` is the OVERKILL condition.
3. **Stage 5 in `resolve_hit`** — call `detect_overkill`, then `classify_damage_tier(damage_dealt, ctx.target_state.max_hp, is_crit)`, then assign `outcome` per Rule 4 step 6.

---

## Out of Scope

- Story 003: Formula 1 base damage (prerequisite)
- Story 004: Crit multiplier (prerequisite)
- Story 009: Integration tests with EnemyDirector VFX dispatch

---

## QA Test Cases

**Story Type**: Logic

- **AC-16**: 5-tier boundary values
  - Given: target.max_hp=1000, is_crit=false
  - When: classify_damage_tier for damage_dealt 9/50/149/400/401
  - Then: LIGHT/MEDIUM/MEDIUM/HEAVY/CRITICAL
  - Edge cases: damage=0 → NEGLIGIBLE; damage=10 (ratio=0.01 exact) → LIGHT (inclusive lower bound)

- **AC-17**: Crit override to ≥HEAVY
  - Given: damage_dealt=20, max_hp=1000, is_crit=true
  - When: classify_damage_tier
  - Then: HEAVY (not LIGHT); also verify damage_dealt=400 + is_crit → still HEAVY (already ≥HEAVY)

- **AC-18**: Overkill clamp
  - Given: damage_raw=200.0, target.hp=50
  - When: detect_overkill
  - Then: damage_dealt=50, overkill_excess=150, is_kill=true, outcome=OVERKILL

- **AC-19**: Exact kill boundary
  - Given: damage_raw=50.0, target.hp=50
  - When: detect_overkill
  - Then: outcome=KILLED (not OVERKILL), overkill_excess=0

- **AC-30**: max_hp=1 no crash
  - Given: max_hp=1, damage_dealt=1
  - When: classify_damage_tier
  - Then: CRITICAL; no NaN/exception

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/test_formula4_damage_tier.gd`, `tests/unit/combat/test_formula5_overkill.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (final_damage_float from crit stage feeds into detect_overkill)
- Unlocks: Story 006 (full resolve_hit purity tests need complete pipeline)
