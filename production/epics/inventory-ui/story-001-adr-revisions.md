# Story 001: G-IU-2 ADR revisions(ADR-0001 layer 61 + capture enumeration / ADR-0008 insertion)

> **Epic**: Inventory UI (#23)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Dependencies G-IU-2 row(完整 spec 喺 gate 行)
**Requirement**: direct GDD trace(G-IU-2)

**ADR Governing Implementation**: ADR-0001(primary)+ ADR-0008
**ADR Decision Summary**: CanvasLayer topology 明文 enumeration;autoload 絕對位置以 project.godot 為 ground truth,amendment 行格式有先例(G-CS-7+8)。

**Engine**: Godot 4.6 | **Risk**: LOW(doc-only)
**Engine Notes**: 機制事實:BackBufferCopy capture 係 positional(<100 全部 — screen_effects.gd L372-373);enumeration 係 doc-contract(verifier-grep 紀律 — 唔同步 = phantom 溫床)

**Control Manifest Rules (Presentation)**: N/A(doc revision)

---

## Acceptance Criteria

- [ ] ADR-0001:InventoryUILayer **61** 註冊(PAUSABLE + pre-warm hidden 注記)+ **L112 + L127 capture enumeration「0/10/50/60」→「0/10/50/60/61」**(G-CS-7 先例格式)+ mood note(saturation chain = identity;LOOT_DROP force-close;CLOSING×OPENING crossfade transient 接受 — 遠低 mobile 150 cap)
- [ ] ADR-0008:amendment row — InventoryUICoordinator tail append 喺 CharacterScreenCoordinator 後;predecessor constraints `{GameStateMachine (C6), InventorySystem, AudioManager, PlatformDetect} ≺ InventoryUICoordinator`;**明文「NO #22 constraint」note**(#19 G-Z-1 先例);明文唔列零接觸 autoloads;#28 keep last
- [ ] technical-preferences.md ADR-0001/0008 行更新(#23 amendment 注記)

## Implementation Notes

- 照抄 G-CS-7/G-CS-8 amendment 行格式(adr-0008 L120-123 現有 rows);ADR-0001 用「#23 revision: +61」格式(L112 現有「#22 revision: +60」隔離)
- 唔掂 project.godot(嗰個係 story 002)

## Out of Scope

- Story 002:coordinator scaffold + project.godot 登記

## QA Test Cases

- **Doc diff**: Given 兩份 ADR,When grep「0/10/50/60/61」+「InventoryUICoordinator」,Then 兩處 enumeration + amendment row + NO-#22 note 齊

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: ADR diffs(grep-verifiable)+ combined CI gate 唔變紅
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: Story 002(scaffold 前提)
