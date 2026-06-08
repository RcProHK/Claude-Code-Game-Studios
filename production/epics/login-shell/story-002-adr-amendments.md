# Story 002: G-LS-1 ADR-0001 + G-LS-2 ADR-0008 amendment(layer 拓撲 + autoload 位置)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data(doc + config)
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 1 + G-LS-1 + G-LS-2)
**Requirement**: G-LS-1 / G-LS-2 gates

**ADR Governing**: ADR-0001(primary — layer 拓撲)+ ADR-0008(autoload 位置)
**ADR Decision Summary**: ADR-0001 = CanvasLayer 拓撲 + capture enumeration + 禁第二 BackBufferCopy;ADR-0008 = project.godot 係 autoload 絕對位置 sole ground-truth,tail-append insertion rule。
**Engine**: Godot 4.6 | **Risk**: LOW(doc)
**Engine Notes**: layer 62/111 數值 = #21/#22/#23 amendment 先例(G-LM-1 / G-CS-7 / G-IU-2)。

**Control Manifest Rules**:
- Required: autoload boot per-instance sequential(ADR-0006 C4);CI `check_loot_reveal_boot_order` allow ADR-0008-sanctioned tail-appends
- Forbidden: 第二個 BackBufferCopy(ADR-0001 #21 blur-CUT 同源)

---

## Acceptance Criteria

*G-LS-1 + G-LS-2(scaffold 前提 — layer/位置 要 ADR 授權先寫 project.godot):*

- [ ] **ADR-0001 amendment**:`LoginShellLayer`(layer 62,PAUSABLE,capture enumeration → 0/10/50/60/61/62)+ `ErrorBannerLayer`(layer 111,ALWAYS,>100 shake/saturation-immune / <120 below #21)+ banner 禁第二 BackBufferCopy 注記
- [ ] **ADR-0008 amendment**:`LoginShellCoordinator` tail append(InventoryUICoordinator 之後;#28 keep last)— 零 #21/#22/#23 constraint
- [ ] CLAUDE.md architecture log 兩 ADR row 更新(G-LM-5 / G-CS-8 / G-IU-2 row 格式先例)

---

## Implementation Notes

- 跟 #22 G-CS-7+8 / #23 G-IU-2 amendment 先例:ADR-0001 文件加 LoginShell row 入 layer table + capture enumeration L107;ADR-0008 加 G-LS-2 insertion rule + predecessor note。
- **本 story doc-only,唔寫 .gd code**;project.godot 實際登記喺 story 003(scaffold)。
- capture enumeration「0/10/50/60/61」→「0/10/50/60/61/62」(LoginShellLayer 62 加入 BackBufferCopy capture 序)。

---

## Out of Scope

- Story 003:project.godot 實際 autoload 登記 + coordinator 實作

---

## QA Test Cases

**Config/Data — smoke check:**

- **G-LS-1/2**: ADR amendment 完整性
  - Setup: 讀 adr-0001 + adr-0008 amended 文件
  - Verify: LoginShellLayer 62 + ErrorBannerLayer 111 + tail insertion rule 三者文字齊;CLAUDE.md log 同步
  - Pass condition: 兩 ADR amendment + CLAUDE.md row 一致,無 layer 數值衝突(grep 62/111 唯一)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-login-shell-adr.md`(ADR amendment 一致性 smoke)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 003(scaffold — layer/位置 ADR 授權前提)
