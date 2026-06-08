# Story 018: G-LS-7 FSM extraction closure(#22/#23 coordinator header fork notice)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data(doc)
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 14 + G-LS-7)
**Requirement**: G-LS-7 — #23 rule-of-three closure（#24 唔觸發 ScreenLifecycleFsm extraction）

**ADR Governing**: N/A — doc closure（godot-specialist 覆核)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #24 三個 lifecycle（login 主畫面 / banner 常駐 / shell entry stateless）都唔 fit #22/#23 五態 overlay FSM → 夾硬 extract = 錯誤抽象。

**Control Manifest Rules**:
- Required: 唔為 rule-of-three 未夠真 instance 做 premature extraction

---

## Acceptance Criteria

*GDD Rule 14 + G-LS-7:*

- [ ] **G-LS-7**: #22/#23 coordinator header 嘅 FSM-extraction fork notice → 加一行 Rule 14 closure 注記（「#24 審視後唔 extract — login ≠ overlay lifecycle;將來如有第三個真 overlay 先 extract」)
- [ ] godot-specialist 覆核 closure 注記（裁決一致性)

---

## Implementation Notes

- #22 `character_screen_coordinator.gd` + #23 `inventory_ui_coordinator.gd` header 各有 FSM-extraction fork notice（留待 #24 裁決）→ 本 story 加 closure 注記指向 GDD Rule 14。
- **doc-only**：唔改 production FSM code（#22/#23 各自 5-態 overlay FSM 不變;#24 唔 extract 共用 base）。
- 將來如有第三個真 overlay（e.g. 獨立 settings screen）先 extract。

---

## Out of Scope

- #22/#23 FSM code 改動（doc-only closure)
- Story 003:#24 coordinator scaffold（本 story 純 doc 注記)

---

## QA Test Cases

- **G-LS-7**: closure 注記
  - Setup: 讀 #22/#23 coordinator header
  - Verify: 兩 header FSM-extraction fork notice 有 Rule 14 closure 注記
  - Pass condition: 注記指向 GDD Rule 14 + godot-specialist 覆核;零 #22/#23 FSM code 改動

---

## Test Evidence

**Story Type**: Config/Data(doc)
**Required evidence**: `production/qa/smoke-login-shell-fsm-closure.md`(doc 注記確認)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None(doc-only)
- Unlocks: None
