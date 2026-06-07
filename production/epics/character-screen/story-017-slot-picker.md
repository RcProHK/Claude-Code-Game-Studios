# Story 017: SLOT_PICKER bottom sheet(slot-filtered + F3 + virtualized)

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rule 17(入口 = empty tap /「更換」;row tap = equip;120 worst case virtualized + count indicator)+ EC-19/20;UX spec Z5 bottom sheet
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0001(AC-49 budget 語境 — virtualized render)secondary
**Engine**: Godot 4.6 | **Risk**: MEDIUM(virtualized list 喺 Compatibility renderer)
**Engine Notes**: 120 張 Control card 同 frame instantiate 撞 mobile 2ms budget — lazy/virtualized(pool 或 visible-range render)

---

## Acceptance Criteria(GDD AC-31)

- [ ] **AC-31** *(G-CS-1 gated — 已解封 by story 010)*:picker 開(empty slot tap / 更換 button)→ 只列 `slot_affinity` match + IN_INVENTORY、F3 排序;0 件 → empty-state sheet 照開(「呢個 slot 暫時冇後備裝備」);stale row equip → not_found → toast + **原地 rebuild**(唔 close)
- [ ] Row:name + rarity badge + `stat_modifiers` 摘要 + locked 標記;**禁 predicted final**(Rule 9/16)
- [ ] Sheet 頂 row count(「34 件」);scroll + virtualized;cosmetic slot → cosmetic-only
- [ ] 邊界:無 search / 無跨 slot / 無 bulk(#23 地盤)

## Implementation Notes

- F3 comparator 用 story 005 API(`get_items_for_slot` → sort → render);rebuild 後空 → EC-20 empty state
- `ui_sheet_open/close` cues;row tap → `equip` → close sheet + story 014 nudge 流程接力

## Out of Scope

- #23 full inventory browse;picker row inspect 通道(MVP 無)

## QA Test Cases

GDD AC-31 GWT embed;120 件 fixture(virtualize assert:instantiated nodes < N);EC-19 原地 rebuild;empty cosmetic slot case

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_commands.gd`(picker cases)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 014 + Story 010(G-CS-1)
- Unlocks: None(leaf)
