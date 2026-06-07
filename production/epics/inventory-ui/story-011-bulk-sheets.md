# Story 011: Bulk sheets — BULK_SELECT(re-preview)+ BULK_CONFIRM(D5 三層 + 三段結構)+ 退層 routing

> **Epic**: Inventory UI (#23)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rules 15/16 + EC-02/03 + States return-target 表 + UX spec BULK wireframes
**Requirement**: direct GDD trace(AC-19 / AC-20 / AC-24)

**ADR Governing Implementation**: ADR-0007(secondary — RarityTier rows)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: preview 係 free synchronous read — sheet enter + row tap 都 re-fetch(Rule 15 pin)

**Control Manifest Rules (Presentation)**: M/K breakdown = view-model count(唔係 selection predicate duplicate — D5 邊界)

---

## Acceptance Criteria

- [ ] **AC-19**:5 rarity rows = preview 真值;0 件 row 灰掉照 tap → **re-preview** → 仍 0 → inline note;owned>0 全 locked →「0 件可分解([N] 件已鎖)」variant;reverse drift(re-preview >0)→ 照開 CONFIRM
- [ ] **AC-20** *(G-IU-1 receipt_ids)*:D5 三層 — ①receipt itemised(`receipt_ids` → `get_item()`;cap 8 +「+N more」總數照報)②conditional「內含信箱 [M] 件、現役 [K] 件」(零中招 assert 無)③`make_room_pending` rarity-match unlocked → 第一行「⚠ 包括你想領取嗰件『[name]』」(無 pending assert 無);**三段結構**(fixed header[receipt 總數 above-fold]+ scrollable 中段 + fixed footer);cancel+scrim+ESC 三者一律退返 BULK_SELECT;default focus = cancel
- [ ] **AC-24**:ESC 逐層(CONFIRM→SELECT[+re-preview]→NONE→close screen);SALVAGE_CONFIRM ESC/scrim/cancel → ITEM_INSPECT;MAKE_ROOM ESC/scrim → NONE

## Implementation Notes

- ENTER 只喺 confirm 獲 focus 時觸發 confirm(default focus cancel — UX spec)
- Modal ≠ NONE ⇒ section tabs scrim 封鎖(MAKE_ROOM「自行整理」係唯一例外路徑)

## Out of Scope

- Story 012:confirm 之後嘅 execute(AC-21/22/23/36)

## QA Test Cases

(= AC GWT;邊界:receipt_count 9[cap 8 + 「+1 more」]/ M=0 K>0 only 現役行 / pending 件 locked[warning 唔出])

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_bulk.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 006 + 003(receipt_ids)+ 009(pending context)
- Unlocks: 012
