# Story 007: R-12 dual-axis decoupling (is_crit vs DamageTier.CRITICAL)

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-12 + EC-13/14 + Damage number 視覺 spec)
**Requirement**: `TR-cvf-007`

**ADR Governing Implementation**: ADR-0009: Signal Payload Schema(primary)
**ADR Decision Summary**: payload 有兩個獨立 field — `is_crit`(crit roll)同 `damage_tier`(ratio-of-maxHP)。#25 screen-feel keyed on `damage_tier`;number style keyed on `is_crit`。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: grep-verified #13 crit-override「every crit reads ≥ HEAVY」(combat_resolver:363)→ `is_crit=true` 之下 tier 只可能 HEAVY/CRITICAL(LIGHT/MEDIUM/NEGLIGIBLE 不可達);EC-13(is_crit+HEAVY)係 reachable。

**Control Manifest Rules (Presentation)**:
- Required: 兩個「critical」語意 impl 嚴格分開
- Forbidden: 用 `is_crit` 驅動 screen-feel,或用 `damage_tier` 驅動 number 暖色
- Guardrail: number style ≠ tier 主載體(foveal bonus only)

---

## Acceptance Criteria

*From GDD R-12 + EC-13/14:*

- [x] **AC-12**:is_crit=true HEAVY → number CRIT + overlay IDLE + hit_pause(0.065);is_crit=false CRITICAL → number PLAIN + overlay FLASHING + hit_pause(0.080)(test_crit_roll_heavy_tier + test_noncrit_critical_tier)
- [x] **EC-13**:is_crit=true HEAVY → CRIT number + HEAVY screen-feel(test_crit_roll_heavy_tier_warm_number_but_heavy_feel)
- [x] **EC-14**:CRITICAL is_crit=false → flash + 80ms + PLAIN number(test_noncrit_critical_tier_plain_number_but_critical_feel)
- [x] number style 純由 `is_crit`(`NumberStyle.CRIT if payload.is_crit else PLAIN`,`_last_number_style`);screen-feel 純由 tier/outcome(F4/wants_flash 已 keyed,兩軸零 cross-wire,test_number_style_is_pure_is_crit)

---

## Implementation Notes

*Derived from ADR-0009:*

- screen-feel routing(pause + flash)= story 005/006 已 keyed on tier/outcome;本 story 加 number-style 分支:`var style = CRIT_STYLE if payload.is_crit else PLAIN_STYLE`,傳俾 number pool acquire(story 009)。
- 兩軸完全獨立:同一 hit 可以「flash(tier CRITICAL)+ 白 number(is_crit false)」或「無 flash(tier HEAVY)+ 暖 number(is_crit true)」。
- crit-override(#13)令 `is_crit=true → tier≥HEAVY`,故 number 暖色只會配 HEAVY/CRITICAL screen-feel(設計一致)。

---

## Out of Scope

- Story 009: number pool 實際 render style(本 story 只決定 style flag)
- Story 010: overlay flash render

---

## QA Test Cases

- **AC-12**: 雙軸解耦
  - Given: `is_crit=true, damage_tier=HEAVY`
  - When: route
  - Then: number style==CRIT(暖橙 bounce flag)+ overlay 不 FLASHING + hit_pause(0.065)
  - Edge cases: `is_crit=false, damage_tier=CRITICAL` → number style==PLAIN + overlay FLASHING + hit_pause(0.080)
- **EC-13 / EC-14**: 兩個合法 cross 組合
  - Given: EC-13(is_crit+HEAVY)/ EC-14(CRITICAL+非crit)
  - Then: 各自 number-style 與 screen-feel 獨立正確(非 bug)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_dual_axis.gd`(AC-12 + EC-13/14;spy number-style flag + overlay state + hit_pause)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_dual_axis.gd` 3/3(EC-13 cross + EC-14 cross + pure-is_crit);cvf unit 23/23

---

## Dependencies

- Depends on: Story 005(screen-feel)、Story 006(kill 分支)
- Unlocks: Story 009(number pool 消費 style flag)
