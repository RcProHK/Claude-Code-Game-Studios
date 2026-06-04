# Story 004: Formula 2 boss_attack_damage_scaling (live-HP)

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Formula 2 (live-HP, Pass 11)
**Requirement**: `TR-boss-008` (boss_attack_damage_scaling; ⚠️ TR text「anti-one-shot」is pre-Pass-11 — GDD reframes to texture-guard / live #13 damage input)

**ADR Governing Implementation**: ADR-0001 (budget/scaling) — primary
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `BossFormulas.compute_attack_damage(...) -> int` static. Output is a REAL damage INPUT to #13 `CombatResolver.compute_hit_damage(boss as attacker)` — #13 owns the avatar HP write, NOT #16.

**Control Manifest Rules (Feature layer)**: pure static helper; reads frozen snapshot (CF-3).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-19**: player_max_hp=200, DAMAGE_RATIO_PER_HIT=0.28, pattern_damage_multiplier=2.5 → `boss_attack_damage ≤ ⌊200×0.5⌋ = 100` always; MAX_BOSS_DAMAGE clamp triggered. (Texture-guard / anti-downed-flicker ceiling, NOT survival one-shot protection — avatar is invincible per EC-25.)
- [ ] CRIT-6 clamp-inversion guard: `MAX_BOSS_DAMAGE = max(⌊player_max_hp × MAX_BOSS_DAMAGE_RATIO⌋, MIN_BOSS_DAMAGE)`; degenerate `player_max_hp ∈ [1,9]` → clamp range collapses to [5,5] (EC-06).
- [ ] CF-2 holds: `boss_attack_damage ≤ max(MIN_BOSS_DAMAGE, ⌊player_max_hp × 0.5⌋)`; INV-5: `MAX_BOSS_DAMAGE_RATIO ≤ 0.5` STRICT.

---

## Implementation Notes

*From GDD Formula 2:*

- `raw = round(player_max_hp × DAMAGE_RATIO_PER_HIT × pattern_damage_multiplier)`; `MAX_BOSS_DAMAGE = max(floor(player_max_hp × MAX_BOSS_DAMAGE_RATIO), MIN_BOSS_DAMAGE)`; `clamp(raw, MIN_BOSS_DAMAGE, MAX_BOSS_DAMAGE)`.
- The output is the per-pattern base number handed to #13. Avatar HP deduction + downed→recover (EC-25) is #13/Story-013 territory, not this formula.
- Reads frozen `snapshot.max_hp` (CF-3), never live StatSystem.

---

## Out of Scope

- **Story 013**: avatar-downed auto-recover + DOWNED_INVULN_SEC grace (the downstream consequence of this damage reaching 0).
- #13 compute_hit_damage (Approved/implemented in #13).

---

## QA Test Cases

- **AC-19**: Given max_hp=200/ratio=0.28/mult=2.5; When compute; Then ≤100 + clamp triggered. Edge: raw before clamp = round(200×0.28×2.5)=140 → clamped 100.
- **EC-06 degenerate**: max_hp=4 → MAX_BOSS_DAMAGE_dynamic=floor(2)=2 < MIN_BOSS_DAMAGE 5 → MAX=5 → clamp [5,5] = 5. max_hp=10 → MAX=5.
- **CF-2 sweep**: across plausible inputs assert output never exceeds the CF-2 bound.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_formula2_one_shot_protection.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (BossFormulas class)
- Unlocks: Story 013 (downed consequence)
