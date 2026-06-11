# Story 010: G-CV-1 overlay primitive (IDLE/FLASHING, F2 latest-wins) + EC-20 degrade

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-11 + Formula 2 + Overlay sub-state + EC-04/20 + AC-24)
**Requirement**: `TR-cvf-010`

**ADR Governing Implementation**: ADR-0001: Web Export Budget Caps(primary)
**ADR Decision Summary**: `CombatOverlayLayer(105)` 全屏 single-instance latest-wins;`ColorRect` + analytic shader(無 texture);≤1 blend pass;105>100 故 shake/BBCopy-immune。ratification-gated(AC-24)。

**Engine**: Godot 4.6 | **Risk**: HIGH(ADR-0001 — fillrate + overlay shader + ratification gate)
**Engine Notes**: `ColorRect.color.a` 或 analytic `canvas_item` shader;IDLE → `visible=false` zero-cost short-circuit;latest-wins reset t=0 + 採新 climax opacity/duration。

**Control Manifest Rules (Presentation)**:
- Required: single-instance latest-wins;IDLE short-circuit zero per-frame cost
- Forbidden: 疊多 overlay(>1 blend pass)
- Guardrail: opacity × `motion_intensity`(story 013);ratification-gated AC-24 用 `pending()`

---

## Acceptance Criteria

*From GDD R-11 + Formula 2 + EC-04/20:*

- [x] **AC-21(Formula 2)**:`overlay_alpha(0.06,0.6,0.12)==0.30`;duration→0;start→peak;clamp;zero-dur safe(test_cvf_overlay_formula 6/6)
- [x] **AC-23**:CRITICAL flash 進行中 route OVERKILL → 仍 1 個 ColorRect(get_child_count==1)+ t reset 0 + 採 OVERKILL 0.6/0.12(test_latest_wins_overkill_replaces_critical)
- [x] **AC-07b(degrade)**:`_overlay_enabled=false` CRITICAL hit → overlay IDLE 不渲染 + 無 crash(test_degrade_no_flash_when_unratified);pause 0.100 path 在 story 005
- [x] **AC-24(ratification-gated ADVISORY)**:`pending("ratification-gated: ADR-0001 CombatOverlayLayer amendment …")` 顯式跳過(test_ac24_real_flash_render_is_ratification_gated),**唔 assert-true 假綠**;state-logic(AC-23/21/degrade)CI-tested
- [x] IDLE → `visible=false` zero per-frame cost(`_tick_overlay` short-circuit `if _overlay_state != FLASHING: return`;test_overlay_decays_to_idle + pre-warm hidden)

---

## Implementation Notes

*Derived from ADR-0001:*

- overlay node = `ColorRect`(全屏)on `CombatOverlayLayer(105)`;IDLE → hidden;FLASHING → visible + `_process` decay `alpha = MAX_OPACITY × max(0, 1-t/DURATION)`(Formula 2);`t≥DURATION → IDLE`。
- latest-wins:新 climax 觸發 → reset t=0 + 採新 climax 嘅 opacity(CRITICAL 0.35 / OVERKILL 0.6)+ duration(CRITICAL 0.18 / OVERKILL 0.12)。≤1 active(EC-04)。
- degrade:若 `overlay_enabled=false`(amendment 未 ratify),overlay 唔渲染,CRITICAL/OVERKILL pause 用 0.100(story 005 已實作 path)。
- analytic shader / 純 `ColorRect.modulate.a`(flat flash 唔需 texture)。

---

## Out of Scope

- Story 013: opacity × motion_intensity(a11y gate)
- Story 005/006: 邊個 outcome/tier 觸發 FLASHING(本 story 只 own overlay primitive)

---

## QA Test Cases

- **AC-21**: Formula 2(deterministic)
  - Given: `MAX_OPACITY=0.6, DURATION=0.12`
  - When: t=0.06 / t≥0.12
  - Then: alpha==0.30 / 0 + IDLE
- **AC-23**: latest-wins
  - Given: CRITICAL flashing,t=0.10
  - When: OVERKILL 觸發
  - Then: 仍 1 active,t reset 0,採 OVERKILL opacity 0.6/dur 0.12
- **AC-24**: gated honesty
  - Given: `overlay_enabled=false`
  - Then: 無 flash + 無 crash;真 flash 渲染 test = `pending()` 跳過（唔 assert-true 假綠）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_overlay_formula.gd`(AC-21 pure)+ `tests/integration/combat_visual_feedback/test_cvf_overlay_latest_wins.gd`(AC-23 + AC-24 pending)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_overlay_formula.gd` 6/6 + `test_cvf_overlay_latest_wins.gd` 5 pass + 1 pending(AC-24 honest)。F2 `overlay_alpha` + 4 overlay knobs @ formulas;`CombatOverlayLayer` 105 + ColorRect + FlashKind + `_tick_overlay` @ coordinator。cvf suite 55 pass / 1 pending / 0 fail。lesson:test 多 hit 要 distinct transition_id 否則 dedup 擋第二 hit

---

## Dependencies

- Depends on: Story 002(CombatOverlayLayer 105)、Story 005/006(觸發 source)
- Unlocks: Story 013(motion_intensity gate)
