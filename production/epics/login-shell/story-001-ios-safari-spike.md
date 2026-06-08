# Story 001: G-LS-6 iOS Safari spike(keyboard / canvas-resize / IME / auto-zoom / dual-focus)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration(engine spike)
> **Estimate**: M(spike — timeboxed)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 13 + G-LS-6 + AC-47)
**Requirement**: TR-login-??? (no TR-ID — GDD 直 trace;G-LS-6 gate)
**UX Spec**: `design/ux/login-gymsys-connection-ui.md`(Accessibility + LZ-Form)

**ADR Governing**: N/A — engine-verification spike(post-cutoff API behavior 實測,非架構模式)
**Engine**: Godot 4.6(Web Export,Compatibility)| **Risk**: **HIGH**
**Engine Notes**: `DisplayServer.virtual_keyboard_show` web 行為 4.6 post-cutoff 未知;**4.6 dual-focus breaking change**(4.5→4.6 把 mouse/touch focus 同 keyboard/gamepad focus 分離 — `grab_focus()` 只郁 keyboard focus);**canvas `LineEdit` 對 iOS = 一整塊 WebGL**,`input font ≥16px` auto-zoom 防護**大機會 no-op**(iOS focus-zoom 由 DOM input font 觸發,canvas 設唔到 engine-internal 隱藏 DOM input)。

**Control Manifest Rules(Presentation)**:
- Required: raw `JavaScriptBridge.eval` 只准喺 `src/autoload/platform_detect.gd`(ADR-001 forbidden pattern)
- Guardrail: web Compatibility renderer;512MB browser ceiling

---

## Acceptance Criteria

*GDD AC-47(EXTERNAL — iOS real-device)+ G-LS-6 route decision:*

- [ ] iOS Safari real-device:keyboard 唔遮 form(或 scroll 補救);submit 可達
- [ ] **canvas LineEdit 路線實測 auto-zoom 是否存在**(16px 對 canvas 大機會 no-op — 唔可預設已解決)
- [ ] **dual-focus 兩種 input(touch-tap + keyboard tab)都驗**(4.6 breaking change)
- [ ] IME 對 ASCII-only credential 行為記錄(風險偏低,verify 一項)
- [ ] VoiceOver 讀 `announce_aria` 公告實機驗(a11y 連帶)
- [ ] **產出 route 裁決**:LineEdit MVP-OK / 必須 DOM `<input>` overlay(經 platform_detect seam)— 結果寫入 Q-LS1 + 決定 story 015 路線

---

## Implementation Notes

- 建一個 minimal Web Export 測試 scene(username/password LineEdit + submit),deploy 上 iOS Safari real-device(或 BrowserStack 等效)。
- 逐項記錄:keyboard 彈出行為 / canvas resize reflow / focus 兩 path / auto-zoom 是否觸發 / VoiceOver。
- 若 LineEdit 喺 iOS Safari 連 keyboard 都彈唔出 → MVP 被迫行 DOM overlay(Q-LS1)。
- **唔寫 production shell code** — 純 spike,結果 = doc(`production/qa/evidence/login-shell/ac47-ios-keyboard.md`)+ route 裁決。

---

## Out of Scope

- Story 003:coordinator scaffold(本 spike 唔建 production coordinator)
- Story 015:login form 實作(本 spike 結果決定其路線)

---

## QA Test Cases

**Manual / EXTERNAL real-device(無自動化 — engine 實機行為):**

- **AC-47**: iOS Safari keyboard + canvas LineEdit
  - Setup: deploy minimal test scene 上 iOS Safari real-device
  - Verify: keyboard 彈出 / form 可達 / auto-zoom 是否觸發 / touch-tap 同 keyboard-tab focus 兩 path / VoiceOver 讀 announce_aria
  - Pass condition: 全部行為記錄在 evidence doc + 明確 LineEdit-vs-DOM route 裁決寫入 Q-LS1

---

## Test Evidence

**Story Type**: Integration(spike)
**Required evidence**: `production/qa/evidence/login-shell/ac47-ios-keyboard.md`(real-device 記錄 + route 裁決)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None(epic 第一個 story)
- Unlocks: Story 015(login form route 依賴本 spike 裁決)
