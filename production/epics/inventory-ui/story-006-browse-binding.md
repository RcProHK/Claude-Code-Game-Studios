# Story 006: View models + browse binding(first-frame reads + filter + count/120 + 現役 badge)

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-08

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rules 5/6/7/8 + EC-09
**Requirement**: direct GDD trace(AC-02 integration 面 / AC-10 / AC-11 / AC-12 / AC-35)

**ADR Governing Implementation**: ADR-0006(secondary — re-read 紀律)+ ADR-0007(RarityTier display)
**ADR Decision Summary**: command-then-re-read + visibility re-read;Rule 5 全套統一 re-read 範圍。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_item()` 回 live ref — view model snapshot 即場 copy 欄位,render 層零 live reference

**Control Manifest Rules (Presentation)**: 零 #17 internal 觸碰(public API only)

---

## Acceptance Criteria

- [x] **AC-10** *(G-IU-1)*:open 第一 frame 五 read 齊(all-inventory[含 EQUIPPED] + mailbox + count + shards + loadout)→ view models built;render 層零 live `EquipmentItem` ref(introspect)
- [x] **AC-11**:真 #17 混合 fixture → F3 排序 byte-identical;EQUIPPED 件照列 +「現役」badge(loadout set O(1) lookup)
- [x] **AC-12**:filter 切換 → view model array **object identity 不變**(零 re-read state-based);filter 0 件 / first-run(ALL+0)兩款 empty copy;section 切返 → re-read(新 object)
- [x] **AC-35**:「[count]/120」readout render + mutation 後更新;零 progress-bar 零變色
- [x] Re-read 範圍統一 = Rule 5 全套(五 read 全重讀 + rebuild — `_reread_all()` 單一入口)

## Implementation Notes

- View model = 純 Dictionary/RefCounted snapshot(name/rarity/provenance 單行/lifecycle/locked/receipt/acquired)
- Filter 係 view predicate 唔改 sort;chips 2 字 CJK 一行(唔 scroll — UI 細節留 scene/skin)
- Shards 顯示用 G-IU-5 formatter(story 017 落地前 placeholder str() + TODO 標記 — AC-21 golden 喺 012 之後先跑)

## Out of Scope

- Story 008:mailbox section render;Story 017:thousands separator formatter

## QA Test Cases

- **AC-10**: Given open,When introspect,Then 五 view model sets 齊 + 零 live ref(duck-check 欄位 copy)
- **AC-11**: Given equipped+inventory 混合,When render,Then F3 序 + 現役 badge 恰好 equipped 件有
- **AC-12**: Given filter WEAPON,When 切 ARMOR,Then 同一 array object(identity);Given section 切返,Then 新 object;empty 兩款 copy assert
- **AC-35**: Given count 117,Then「117/120」;When salvage 一件,Then「116/120」

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_browse.gd`
**Status**: [x] Created — +4 tests(AC-10/11/12/35,真 #17 fixture)全 pass;combined gate CLEAN 2298/2297/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 5/5 passing
**Deviations**: None — view model = Dictionary snapshot(欄位 copy,零 live ref — AC-10 mutate-after 證明);`CHIP_TO_SLOT` mapping 收喺 coordinator(formula 層零 enum coupling);MAX_INVENTORY referenced;shards display placeholder `str()` + TODO(story 017 G-IU-5)
**Test Evidence**: +4 integration tests — 五 read + snapshot / F3 序 + badge / filter identity + section re-read + 兩款 empty copy / count readout mutation 更新
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 003 + 004 + 005
- Unlocks: 008/009/010/011/013(全部 render/flow stories)
