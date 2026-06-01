# Story 010: HUD Toggle + CanvasLayer Topology

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30** — CanvasLayer topology owner)
**ADR Decision Summary**: `HUD_SHAKES_WITH_WORLD` knob（default true）控制 HUDLayer 喺 ScreenEffectsLayer 之上定之下。CanvasLayer topology：GameLayer(0) / ParticleLayer(10) / HUDLayer(50) / ScreenEffectsLayer(100, ALWAYS)。true → HUD < SE layer（HUD 跟 shake，DNF unified feel）；false → HUD > SE layer（HUD immune，readability）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ScreenEffects autoload 唔 own scene node — topology 由 master scene / ADR-0001 own。呢個 story 主要係 visual evidence（screenshot）+ optional structural micro-test（CanvasLayer.layer numeric ordering）。Visual co-movement 需截圖（headless 唔 render）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: HUD toggle 跟 CanvasLayer layer ordering（true: HUD<SE / false: HUD>SE）
- Forbidden: ScreenEffects 直接 own/mutate HUD node
- Guardrail: max shake 1.44px << 36px oversample bleed（無 edge clipping）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story（Visual/Feel — ADVISORY gate）:*

- [ ] **AC-20** [AC-G4] — `HUD_SHAKES_WITH_WORLD = true`（default）→ HUDLayer position < ScreenEffectsLayer → HUD pixels 隨 shake 位移；`= false` → HUDLayer > ScreenEffectsLayer → HUD pixels 留 identity transform（visual diff）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 14:*

- `HUD_SHAKES_WITH_WORLD` knob（default true）。Compile-time layer assignment based on initial value（V1 simplest，per Q-F5 default — no runtime toggle）。
- topology（master scene，ADR-0001 input scope）：true → HUDLayer.layer < ScreenEffectsLayer.layer（被 BackBufferCopy capture → shake）；false → HUDLayer.layer > ScreenEffectsLayer.layer（免 capture）。
- ScreenEffects 唔 own topology node — 只 reference knob + 寫 shader uniform。實際 layer 安排由 master scene owner（ADR-0001 / #22）。
- 注意：Q-F5 — runtime in-session toggle（e.g. boss fight auto-disable）係 future refactor，V1 compile-time。

---

## Out of Scope

*Handled by neighbouring stories / deferred:*

- Story 002/003: shake offset 本身（呢度只驗 HUD layer 跟唔跟）
- #22 Character Screen: toggle UI surface / runtime swap mechanism
- master scene topology enforcement（ADR-0001 input scope / Q-F4）

---

## QA Test Cases

*Visual/Feel — manual screenshot evidence（ADVISORY gate）。Optional structural micro-test 補充。*

- **AC-20**: HUD toggle visual diff
  - Setup: 啟動到有 HUD + world sprite 嘅 scene（combat test）；確認 `HUD_SHAKES_WITH_WORLD` default true；觸發強 shake（debug hotkey 或 `shake(1.0, 0.5)`）
  - Verify（true — HUD shakes with world）: 截 shake 高峰幀，HUD 元素（血條/計時器）同 world 一齊位移；CanvasLayer numeric `HUDLayer.layer < ScreenEffectsLayer.layer`
  - Verify（false — HUD anchored）: toggle false，重複 shake 截圖，HUD rock-steady 只 world 震；`HUDLayer.layer > ScreenEffectsLayer.layer`
  - Pass condition: true 並排（rest vs shake-peak）顯示 HUD+world 一齊位移 + layer HUD<SE；false 顯示 world 位移但 HUD 像素不動 + layer HUD>SE；兩對比圖 + lead sign-off 寫入 `production/qa/evidence/screen-effects-ac20-[date].md`
  - Optional headless micro-test（非 evidence gate）: 實例化 topology scene，assert 兩個 CanvasLayer `.layer` numeric ordering 隨 toggle 翻轉（證 numeric ordering；visual co-movement 仍需截圖）

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/screen-effects-ac20-[date].md` — 截圖（true/false 並排）+ lead sign-off（ADVISORY）
- Optional: `tests/unit/screen_effects/test_screen_effects_hud_layer_ordering.gd`（structural numeric ordering）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（shake offset 存在先睇到 HUD 跟唔跟）
- Unlocks: #22 Character Screen（HUD toggle UI surface，pending GDD）
