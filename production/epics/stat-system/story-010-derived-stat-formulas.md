# Story 010: Derived Stat Formulas F3-F6 + CF-1 Baseline

> **Epic**: Stat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 4/4 passing (AC-26 ✓ AC-27 ✓ AC-28 ✓ AC-29 ✓)
**Deviations**: None — F3-F6 replace the 0.0 placeholder; baselines MAX_HP=160/ATK=28/MOVE=184/CRIT=0.015. Regression: updated `test_stat_surface_locked.gd` (derived baseline) + `test_equipment_modifier_allow_list.gd` (5 tests rebased off 160) which previously assumed the 0.0 placeholder
**Test Evidence**: Logic — `test_formula3_max_hp.gd`, `test_default_baseline.gd`, `test_formula5_move_cap.gd`, `test_formula6_crit_cap.gd`
**Code Review**: Complete (Batch C) — formulas + maxi/minf math verified against baselines

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-012`
*(TR-stat-012: 6 derived formulas — MAX_HP / ATTACK_POWER / MOVE_SPEED / CRIT_CHANCE (+ VOLUME_TICK delta / PR_BREAKTHROUGH delta in Story 011))*

**ADR Governing Implementation**: ADR-0006 State Machine Contract — (no direct contract; pure function constraint from Pillar 2 frictionless < 0.01ms per call)
**ADR Decision Summary**: All derived stat formulas are pure functions, O(1), no allocation. They read from `_base` + sum `_equipment_modifiers` at call time — no cache. CombatResolver (#13) calls `get_stat()` on hot path; these formulas must be cheap enough not to bottleneck combat ticks.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript `float` arithmetic is 64-bit double precision. `min(a, b)` for soft cap, `max(1, v)` for floor. Integer cast `int(v)` for MAX_HP / ATTACK_POWER (GDD specifies `int` return type). Derived stats are computed on-read, NOT cached; `get_stat(ATTACK_POWER)` runs the formula every call.

**Control Manifest Rules (Core layer)**:
- Required: Derived stats computed on every `get_stat()` call — NOT cached in a separate field
- Required: All derived formulas use additive (not multiplicative) equipment modifier stacking — INV-4 STR-dominates enforcement
- Forbidden: Never persist derived stats to `stat.*` namespace — only base stats (STR/DEX/VIT) are persisted

---

## Acceptance Criteria

- [ ] **AC-26** — GIVEN VIT=10, no equipment modifiers, default knobs (HP_BASE=80, HP_PER_VIT=8.0), WHEN `get_stat(StatId.MAX_HP)` is called, THEN returns `160` (80 + 10×8.0 + 0); AND WHEN `apply_equipment_modifier("armor_01", StatModifier{MAX_HP: +50})` is called, THEN `get_stat(MAX_HP)` returns `210`.
- [ ] **AC-27** — GIVEN STR=DEX=VIT=10, no equipment, default knobs (ATK_BASE=10, ATK_PER_STR=1.5, ATK_PER_DEX=0.3), WHEN `get_stat(StatId.ATTACK_POWER)` is called, THEN returns `28` (10 + 10×1.5 + 10×0.3 + 0). This is the CF-1 default baseline.
- [ ] **AC-28** — GIVEN DEX=600, equipment_move_mod=+20.0, default knobs (MOVE_BASE=180.0, MOVE_PER_DEX=0.4, MOVE_CAP=420.0), WHEN `get_stat(StatId.MOVE_SPEED)` is called, THEN returns `420.0` exactly (`min(180 + 600×0.4 + 20, 420) = min(440, 420) = 420`).
- [ ] **AC-29** — GIVEN DEX=400, equipment_crit_mod=+0.10, default knobs (CRIT_PER_DEX=0.0015, MAX_CRIT_CHANCE=0.50), WHEN `get_stat(StatId.CRIT_CHANCE)` is called, THEN returns `0.50` exactly (`min(400×0.0015 + 0.10, 0.50) = min(0.70, 0.50) = 0.50`).

---

## Implementation Notes

*From GDD Formulas 3-6 + CF-1 + CF-4:*

1. **Formula 3 — MAX_HP**:
   ```gdscript
   func _compute_max_hp() -> int:
       var e_h := _sum_equipment_mod(StatId.MAX_HP)
       return max(1, int(HP_BASE + _base[StatId.VIT] * HP_PER_VIT + e_h))
   ```

2. **Formula 4 — ATTACK_POWER**:
   ```gdscript
   func _compute_attack_power() -> int:
       var e_a := _sum_equipment_mod(StatId.ATTACK_POWER)
       return max(1, int(ATK_BASE + _base[StatId.STR] * ATK_PER_STR + _base[StatId.DEX] * ATK_PER_DEX + e_a))
   ```

3. **Formula 5 — MOVE_SPEED**:
   ```gdscript
   func _compute_move_speed() -> float:
       var e_m := _sum_equipment_mod(StatId.MOVE_SPEED)
       return min(MOVE_BASE + _base[StatId.DEX] * MOVE_PER_DEX + e_m, MOVE_CAP)
   ```

4. **Formula 6 — CRIT_CHANCE**:
   ```gdscript
   func _compute_crit_chance() -> float:
       var e_c := _sum_equipment_mod(StatId.CRIT_CHANCE)
       return min(_base[StatId.DEX] * CRIT_PER_DEX + e_c, MAX_CRIT_CHANCE)
   ```

5. **`_sum_equipment_mod(stat_id: StringName) -> float`** — sum all `_equipment_modifiers[eq_id].deltas.get(stat_id, 0.0)` across all equipped items.

6. **`get_stat(stat_id: StringName)`** dispatch:
   ```gdscript
   match stat_id:
       StatId.STR, StatId.DEX, StatId.VIT: return _base[stat_id]
       StatId.MAX_HP: return _compute_max_hp()
       StatId.ATTACK_POWER: return _compute_attack_power()
       StatId.MOVE_SPEED: return _compute_move_speed()
       StatId.CRIT_CHANCE: return _compute_crit_chance()
       _: push_error(...); return NAN
   ```

7. **CF-4 floor** — `max(1, ...)` for HP and ATK ensures non-zero even with negative equipment mods.

---

## Out of Scope

- Story 011: VOLUME_TICK delta (Formula 1) + PR_BREAKTHROUGH delta (Formula 2)
- Story 012: Cross-knob invariant tests (verify formula outputs against knob safe ranges)

---

## QA Test Cases

**Story Type**: Logic (all unit tests, pure function — deterministic)

- **AC-26**: MAX_HP formula
  - Given: VIT=10, no eq
  - When: `get_stat(MAX_HP)`
  - Then: Returns 160 (int)
  - Then: After `apply_equipment_modifier("armor", StatModifier{MAX_HP:+50})` → returns 210
  - Edge cases: VIT=0, no eq → `max(1, 80+0+0) = 80`; negative equipment mod → `max(1, ...)` floor

- **AC-27**: ATTACK_POWER CF-1 baseline
  - Given: STR=DEX=VIT=10, no eq, default knobs
  - When: `get_stat(ATTACK_POWER)`
  - Then: Returns 28 (int) — CF-1 hard-pinned baseline
  - Edge cases: Pure push spec (STR=200, DEX=10, no eq) → 10 + 300 + 3 = 313; STR=0 → `max(1, 10+0+0) = 10`

- **AC-28**: MOVE_SPEED cap boundary
  - Given: DEX=600, eq_move=+20, default knobs
  - When: `get_stat(MOVE_SPEED)`
  - Then: Returns 420.0 exactly (cap hit)
  - Edge cases: DEX=10, no eq → 180+4+0=184 (below cap); DEX=0 → MOVE_BASE=180 (floor)

- **AC-29**: CRIT_CHANCE cap
  - Given: DEX=400, eq_crit=+0.10
  - When: `get_stat(CRIT_CHANCE)`
  - Then: Returns 0.50 (cap hit)
  - Edge cases: DEX=10, no eq → 0.015 (1.5%); DEX=333, no eq → 0.4995 (just under cap)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/stat_system/test_formula3_max_hp.gd`, `test_default_baseline.gd`, `test_formula5_move_cap.gd`, `test_formula6_crit_cap.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (equipment modifier layer — formula reads from `_equipment_modifiers`), Story 002 (StatId constants)
- Unlocks: Story 012 (cross-knob invariants validate formula outputs against knob ranges)
