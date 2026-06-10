# Story 003: Formula 1 — dominant_class derivation + class purity

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` Formula 1 / CR-3 / CR-16 / EC-CLASS-1/2 / EC-SIG-3/4
**Requirement**: AC-03(GDD 直接 trace);CR-16 class-derivation purity(AC-27 lint 喺 story 017 驗)
**ADR Governing Implementation**: ADR-0007 Class Enum Convention(primary)
**ADR Decision Summary**: AbilityClass {STRIKE,CONTROL,MOBILITY,UNKNOWN};Classification enum,declaration order load-bearing。#26 class posture 用 STRIKE/CONTROL/MOBILITY(zero-default fabrication forbidden — 但 fresh account all-0 → STRIKE 係 deterministic tie-break,非 fabrication)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `#11.get_stat(stat_id) -> float`(`stat_system.gd:511`);lowercase StringName ids `"str"/"dex"/"vit"`。

**Control Manifest Rules (Presentation layer)**:
- Required: `dominant_class` 用 ONLY `#11.get_stat(STR/DEX/VIT)` 3 base stat(CR-16)
- Forbidden: derive from derived-stat / ability count / loot / streak / workout history
- Guardrail: deterministic tie-break,無 RNG/time-dependence

---

## Acceptance Criteria

- [ ] **AC-03**: STR=DEX=VIT=50 → `dominant_class==STRIKE`(tie-break order STRIKE>CONTROL>MOBILITY)
- [ ] Formula 1 top-down `>=` chain:STR≥DEX∧STR≥VIT→STRIKE;DEX≥VIT→CONTROL;else MOBILITY
- [ ] EC-CLASS-1:three-way tie(all 0)→ STRIKE T0 valid
- [ ] EC-CLASS-2:two-way top tie STR=DEX>VIT → STRIKE
- [ ] EC-SIG-3:`get_stat()` 返 NaN/−1 sentinel → treat as 0(never propagate NaN into tie-break);log `stat_sentinel_received`
- [ ] EC-SIG-4:negative stat → clamp 0 before F1;log `negative_stat_received` CRITICAL
- [ ] CR-16 purity:derivation path 只 reference `get_stat("str"/"dex"/"vit")`

---

## Implementation Notes

*Derived from Formula 1 + CR-3/CR-16:*

```
# inputs: STR, DEX, VIT from #11.get_stat (lowercase ids)
if STR >= DEX and STR >= VIT: return STRIKE
elif DEX >= VIT:              return CONTROL
else:                         return MOBILITY
```

- 純函數,deterministic;tie-break 由 top-down `>=` chain 自動實現(STR head → STRIKE)。
- input sanitize 喺 F1 入口:NaN/sentinel/negative → 0(EC-SIG-3/4),再入 chain。
- output 必係 exactly 1 of {STRIKE,CONTROL,MOBILITY}(CF-1)— never null/multiple。
- re-eval trigger:`#11.stat_changed` where `stat_id ∈ {str,dex,vit}`;sprite swap 服從 CR-9 hysteresis(story 008,本 story 只算 class,唔做 swap timing)。

---

## Out of Scope

- Story 008:posture swap hysteresis / workout-window lock(本 story 只算 dominant_class 值)
- Story 004:evolution_tier(Formula 2)
- Story 017:CI-5 class purity lint(AC-27)

---

## QA Test Cases

- **AC-03**: tie-break
  - Given: STR=DEX=VIT=50
  - When: Formula 1
  - Then: STRIKE
  - Edge cases: golden vector 全表(50/30/20→STRIKE;30/50/20→CONTROL;20/30/50→MOBILITY;40/40/20→STRIKE;20/40/40→CONTROL;0/0/0→STRIKE)
- **EC-SIG-3/4**: sanitize
  - Given: get_stat 返 NaN / −5
  - When: Formula 1
  - Then: 當 0 入 chain;無 NaN propagate;log fired
  - Edge cases: NaN tie-break 唔 crash;negative → 0 → 可能 STRIKE default

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/avatar_renderer/formula1_dominant_class_test.gd` — must pass;golden-vector table-driven,deterministic
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(derivation pipeline + get_stat seam)
- Unlocks: Story 004(Formula 2 用 class context)/ Story 008(posture swap 用 class value)
