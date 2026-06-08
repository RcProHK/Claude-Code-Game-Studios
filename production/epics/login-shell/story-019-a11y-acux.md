# Story 019: a11y(announce_aria + tab order + 44/48px)+ AC-UX layout assertions

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(UI Requirements + Visual/Audio)
**UX Spec**: `design/ux/login-gymsys-connection-ui.md`(Accessibility + AC-UX-1..11 + Banner Region Pixel Pin)
**Requirement**: WCAG AA Core + Motion Safety;UX layout/pixel 兌現

**ADR Governing**: N/A — a11y seam shipped(#21/#22/#23)+ ADR-0001(layer region)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: canvas 對 DOM accessibility tree 不透明 → SR 公告必經 `PlatformDetect.announce_aria` JS-bridge（唔靠 4.5 AccessKit — canvas VoiceOver 讀唔到);seam #21/#22/#23 已 ship。

**Control Manifest Rules**:
- Required: raw JavaScriptBridge.eval 只准喺 platform_detect.gd（announce_aria 經此 seam）
- Required: 所有 gameplay-critical UI ≥44×44px;color-independent（≥2 non-color signal）

---

## Acceptance Criteria

*UX Spec AC-UX-2/3/5/8/9 + GDD a11y UI Requirements:*

- [ ] **AC-UX-2**: R-Default banner `rect.size.y == clamp(round(0.10×H), 44, 72)`,bottom-anchored,full-width(±16);跨 360×640/360×560/desktop;small-viewport(`0.10×H<44`)→ 44px floor 勝
- [ ] **AC-UX-3**: GSM=REST_PERIOD + persistent banner → collapse R-Glyph(top-right 16×16),`R-Glyph ∩ Z5 == ∅`;REST 完 re-expand
- [ ] **AC-UX-5**: 入口卡 enabled `a==1.0` / race interactive-dimmed `a==0.55` tappable / workout hidden 唔 render
- [ ] **AC-UX-8**: toggle/submit/retry/reconnect/gear ≥44×44px;entry card ≥48px
- [ ] **AC-UX-9**: shell state 轉場 cross-fade ≤ `SHELL_FADE_SEC`(0.25s);banner scene 零 AnimationPlayer/tween
- [ ] **announce_aria**：error 公告 = `assertive`,banner = `polite`,皆經 `PlatformDetect.announce_aria`;banner 出現唔搶 form focus
- [ ] **color independence**：error ⚠ / disconnect ⃠ slash / done ✓ / info ⓘ glyph（非色 encode）

---

## Implementation Notes

- SR 公告（error/banner/status/drain）經 `PlatformDetect.announce_aria`（seam #21/#22/#23 已 ship);error assertive / banner polite。
- keyboard tab order：LOGIN(username→password→toggle→submit)/ SHELL_IDLE(char→inventory→gear);banner 出現唔搶 form focus。
- AC-UX region 量度（measure rect）：R-Default ≤10% / R-Glyph ∩ Z5 零 overlap / 入口卡三態 alpha / cross-fade ≤0.25s。
- touch target ≥44px(≥48 entry card);color-independent glyph 雙 encode（squint test）。
- AC-UX-4(單 toast slot 互斥)= **GATED OQ-UX2**（跨系統機制未定 — mock-scoped observe shared flag;真接線 epic/architecture)。

---

## Out of Scope

- Story 016:banner static-CI grep（本 story 做 announce_aria + region measure）
- Story 001:iOS real-device a11y（AC-47 EXTERNAL spike 連帶）

---

## QA Test Cases

- **AC-UX-2**: banner region
  - Given: viewport 360×640/360×560/desktop;When: R-Default render;Then: rect.size.y == clamp(0.10×H,44,72) bottom-anchored full-width
  - Edge cases: H<440 → 44px floor 勝 peripheral %
- **AC-UX-3**: REST 讓位
  - Given: GSM=REST_PERIOD + persistent banner;When: yield;Then: R-Glyph top-right 16×16 + R-Glyph∩Z5==∅;REST 完 re-expand
- **AC-UX-5/8/9**: 三態 / target / cross-fade
  - Given: SHELL states;When: render/transition;Then: 入口卡 a==1.0/0.55/hidden;target ≥44/48px;cross-fade ≤0.25s;banner 零 AnimationPlayer
- **announce_aria**: SR
  - Given: error/banner fire;When: announce;Then: 經 PlatformDetect.announce_aria(assertive/polite);banner 唔搶 form focus

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_a11y_acux.gd` + manual `production/qa/evidence/login-shell/acux6-tab-order.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004/010/013/015(FSM + banner + entry + form 全部 render 後量度)
- Unlocks: None(epic 收口)
