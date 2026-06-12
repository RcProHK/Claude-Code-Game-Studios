# Story 013: G-OB-3 ADR-0001 OnboardingOverlayLayer amendment + coach-mark overlay UI

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Visual §OnboardingOverlayLayer / Rule 1 / Rule 4 / G-OB-3)
**UX**: `design/ux/onboarding-flow.md`（Layout zones / coach-mark card / single slot / Transitions）
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0001: Web Export Budget Caps(primary)
**ADR Decision Summary**: CanvasLayer topology;>100 = BackBufferCopy-immune;<100 captured band;opacity-only backdrop 禁 2nd BBCopy。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `OnboardingOverlayLayer` **captured band <100**（R-2:coach-mark 永不同 world desaturation 同框 → 無需 >100 immune;候選 ~63,above #24 LoginShellLayer 62）。BBCopy capture enumeration 係 positional <100 全 capture — enumeration 明寫 sync（[[feedback_lint_allowlist_adr_sync]] 防 stale-enumeration phantom,G-CS-7/G-IU-2/G-LS-1/G-CV-1 先例）。pre-warmed `visible=false` idle 零 draw-call。

**Control Manifest Rules(this layer)**:
- Required: CanvasLayer pre-warmed hidden;coach-mark 高飽和 HUD-class text;fade 純 opacity
- Forbidden: BackBufferCopy（無 blur — ADR-0001 #21/#24 裁決同源）;搶 #21 loot 110 / #24 banner 111 之上
- Guardrail: single coach-mark slot;peripheral anchor 唔遮中央互動

---

## Acceptance Criteria

- [ ] **G-OB-3 ADR-0001 amendment** — `OnboardingOverlayLayer` layer 數值釘喺既有 enumeration（captured band <100,候選 ~63 above #24 LoginShellLayer 62）;BBCopy capture enumeration 明寫 sync;opacity-only NO BackBufferCopy。
- [ ] coach-mark card 視覺:peripheral 位置、貼近相關 element、細高飽和 text card、fade in/out（`coach_fade_sec` 0.25s）;**零 pulse / 零 gaze-drawing animation**（#24 banner / P-17 restraint）。
- [ ] 單一 coach-mark slot（同時最多一個;EC-13 queue by step order）。
- [ ] dismissible affordance visible（tap hint glyph 或自然 auto-fade）。
- [ ] `OnboardingOverlayLayer` pre-warmed `visible=false`（idle 零 draw-call;AC-01 確認）。

---

## Implementation Notes

*Derived from ADR-0001 / GDD Visual:*

- ADR-0001 amendment row（`OnboardingOverlayLayer` captured-band entry + BBCopy enumeration sync;格式跟 G-LS-1 / G-CV-1 amendment）。**Impl-time 確認既有 captured-band enumeration**（`src/autoload/screen_effects.gd` L370-371 positional <100;現有 0/10/15*/50/60/61/62）→ 加 onboarding layer int。
- `src/ui/onboarding/coach_mark.gd`（helper）:text card render,peripheral anchor,fade（opacity tween,`coach_fade_sec`;reduced-motion → 0）。
- single slot:coordinator 保證同時最多一 coach-mark（Formula 1 `no_other_coachmark_visible`）。
- **無 BackBufferCopy**（AC enforce `find_children("*","BackBufferCopy")` empty,#24 AC-36 先例）。
- coach-mark 高飽和 amber-gold / warm-white（HUD palette;但 R-2:desaturation immunity moot,因永不同 world desaturation 同框）。

---

## Out of Scope

- Story 014: a11y announce / reduced-motion / escape hatch（呢度視覺 layout + layer;a11y 喺 014）。
- Story 005/006: may_show / dismiss 邏輯（呢度 render surface）。
- UXQ-02/04: coach-mark card / watermark 確切美術（epic-time `/asset-spec`）。

---

## QA Test Cases

**G-OB-3(layer amendment)**:
- Given: `OnboardingOverlayLayer` instantiated
- When: 讀 layer int
- Then: <100（captured band,候選 ~63 above #24 62）;NO BackBufferCopy child;pre-warmed visible=false
- Edge cases: BBCopy capture enumeration 明寫含 onboarding layer（positional + explicit sync）

**Coach-mark render**:
- Setup: trigger 一個 coach-mark（非 critical state）
- Verify: peripheral 位置、貼近 element、fade-in（無 pulse）、dismiss affordance visible、single slot
- Pass condition: 同時最多一 coach-mark;fade 純 opacity;零 BackBufferCopy

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `tests/integration/onboarding_flow/test_overlay_layer.gd`（layer <100 + NO BBCopy + pre-warmed + single-slot）+ `production/qa/evidence/onboarding-coachmark-evidence.md`（視覺 restraint 人手）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（OnboardingOverlayLayer instantiate）
- Unlocks: Story 014（a11y 疊喺 overlay）
